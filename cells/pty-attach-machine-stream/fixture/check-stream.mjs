#!/usr/bin/env node
import fs from "node:fs"
import assert from "node:assert/strict"

const geometry = (rows, columns) => {
  const payload = Buffer.alloc(4)
  payload.writeUInt16BE(rows, 0)
  payload.writeUInt16BE(columns, 2)
  return payload
}

const frame = (type, payload) => {
  const header = Buffer.alloc(5)
  header.writeUInt8(type)
  header.writeUInt32BE(payload.length, 1)
  return Buffer.concat([header, payload])
}

const decode = (data, complete) => {
  const packets = []
  let offset = 0
  while (offset + 5 <= data.length) {
    const type = data.readUInt8(offset)
    const length = data.readUInt32BE(offset + 1)
    if (length > 32 * 1024 * 1024) throw new Error(`oversized frame: ${length}`)
    if (offset + 5 + length > data.length) break
    packets.push({ type, payload: data.subarray(offset + 5, offset + 5 + length) })
    offset += 5 + length
  }
  if (complete && offset !== data.length) throw new Error("truncated trailing frame")
  return packets
}

const snapshotIndexes = (packets) => {
  const indexes = []
  for (let index = 0; index + 1 < packets.length; index++) {
    if (packets[index].type === 10 && packets[index + 1].type === 5) indexes.push(index)
  }
  return indexes
}

const parseGeometries = (raw) => raw.split(",").map((entry) => {
  const match = /^(\d+)x(\d+)$/.exec(entry)
  if (!match) throw new Error(`invalid expected geometry: ${entry}`)
  return { rows: Number(match[1]), columns: Number(match[2]) }
})

const validateSnapshots = (packets, expectedGeometries, count) => {
  const indexes = snapshotIndexes(packets)
  if (indexes.length < count) throw new Error(`expected ${count} snapshots, got ${indexes.length}`)
  for (let snapshot = 0; snapshot < count; snapshot++) {
    const payload = packets[indexes[snapshot]].payload
    const expected = expectedGeometries[snapshot]
    if (!expected || payload.length !== 4 || payload.readUInt16BE(0) !== expected.rows ||
        payload.readUInt16BE(2) !== expected.columns) {
      throw new Error(`snapshot ${snapshot + 1} geometry does not match ${expected?.rows}x${expected?.columns}`)
    }
  }
  return indexes
}

const validateFinal = (data, expectedGeometries, stdout = Buffer.alloc(0), stderr = Buffer.alloc(0)) => {
  const packets = decode(data, true)
  if (packets.length < 5) throw new Error("too few frames")
  if (packets[0].type !== 10 || packets[1].type !== 5) {
    throw new Error("initial stream does not begin with GEOMETRY, SCREEN")
  }
  const indexes = validateSnapshots(packets, expectedGeometries, expectedGeometries.length)
  if (indexes.length !== expectedGeometries.length) {
    throw new Error(`expected ${expectedGeometries.length} snapshots, got ${indexes.length}`)
  }
  const initial = packets[indexes[0] + 1].payload
  const reconnected = packets[indexes[1] + 1].payload
  const coloredMarker = Buffer.from("\x1b[31mINITIAL_COLOR_61e8")
  if (!initial.includes(coloredMarker) || !reconnected.includes(coloredMarker)) {
    throw new Error("snapshot lost the red SGR state around the initial marker")
  }
  if (!reconnected.includes(Buffer.from("AFTER_DROP_61e8"))) {
    throw new Error("reconnect screen is not the current terminal state")
  }
  const exits = packets.filter((packet) => packet.type === 4)
  if (exits.length !== 1 || packets.at(-1).type !== 4) throw new Error("stream does not end in one EXIT")
  if (!packets.some((packet) => packet.type === 0 && packet.payload.includes(Buffer.from("FINAL_DATA_61e8")))) {
    throw new Error("final terminal DATA was not ordered before EXIT")
  }
  if (packets.some((packet) => ![0, 4, 5, 10].includes(packet.type))) {
    throw new Error("unexpected packet type in machine stream")
  }
  if (stdout.length !== 0) throw new Error("machine attach wrote to stdout")
  for (const marker of ["INITIAL_COLOR_61e8", "AFTER_DROP_61e8", "FINAL_DATA_61e8"]) {
    if (stderr.includes(Buffer.from(marker))) throw new Error(`terminal marker leaked to stderr: ${marker}`)
  }
}

const selfTest = () => {
  const expected = parseGeometries("24x80,13x47")
  const colored = Buffer.from("\x1b[31mINITIAL_COLOR_61e8\x1b[0m")
  const current = Buffer.concat([colored, Buffer.from("\r\nAFTER_DROP_61e8")])
  const packets = [
    frame(10, geometry(24, 80)), frame(5, colored),
    frame(10, geometry(13, 47)), frame(5, current),
    frame(0, Buffer.from("FINAL_DATA_61e8")), frame(4, Buffer.alloc(0)),
  ]
  const valid = Buffer.concat(packets)
  validateFinal(valid, expected)
  const uncolored = Buffer.from("\x1b[HINITIAL_COLOR_61e8\x1b[0m")
  const mutations = [
    () => validateFinal(Buffer.concat([frame(10, geometry(1, 1)), ...packets.slice(1)]), expected),
    () => validateFinal(Buffer.concat([frame(10, geometry(24, 80)), frame(5, uncolored), ...packets.slice(2)]), expected),
    () => validateFinal(Buffer.concat([packets[0], packets[1], packets[2], frame(5, colored), ...packets.slice(4)]), expected),
    () => validateFinal(Buffer.concat([...packets.slice(0, 4), packets[5], packets[4]]), expected),
    () => validateFinal(valid.subarray(0, valid.length - 1), expected),
    () => validateFinal(valid, expected, Buffer.from("unexpected")),
    () => validateFinal(valid, expected, Buffer.alloc(0), Buffer.from("FINAL_DATA_61e8")),
  ]
  for (const mutate of mutations) assert.throws(mutate)
  console.log("ORACLE-MUTATIONS-GREEN-61e8")
}

if (process.argv[2] === "--self-test") {
  selfTest()
} else {
  const [path, mode, expectedRaw, geometryRaw, stdoutPath, stderrPath] = process.argv.slice(2)
  if (!path || !mode || !expectedRaw || !geometryRaw) process.exit(2)
  const data = fs.existsSync(path) ? fs.readFileSync(path) : Buffer.alloc(0)
  const expected = Number(expectedRaw)
  const expectedGeometries = parseGeometries(geometryRaw)
  if (mode === "snapshots") {
    validateSnapshots(decode(data, false), expectedGeometries, expected)
  } else if (mode === "final") {
    if (!stdoutPath || !stderrPath) process.exit(2)
    validateFinal(data, expectedGeometries, fs.readFileSync(stdoutPath), fs.readFileSync(stderrPath))
    console.log("PACKAGED-FD-GREEN-61e8")
    console.log("INITIAL-SNAPSHOT-GREEN-61e8")
    console.log("RECONNECT-SNAPSHOT-GREEN-61e8")
    console.log("FRAMED-TERMINAL-STREAM-GREEN-61e8")
  } else {
    process.exit(2)
  }
}
