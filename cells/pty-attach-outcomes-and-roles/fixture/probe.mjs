#!/usr/bin/env node
import assert from "node:assert/strict"
import fs from "node:fs"
import net from "node:net"
import os from "node:os"
import path from "node:path"
import { spawn, spawnSync } from "node:child_process"

const TYPE = { DATA: 0, ATTACH: 1, DETACH: 2, RESIZE: 3, EXIT: 4, SCREEN: 5, PEEK: 6, STATUS: 7, GEOMETRY: 10 }
const OUTCOMES = new Set([TYPE.DETACH, TYPE.EXIT])
const PTY = process.env.PTY_BIN ?? "pty"
const root = process.env.PTY_EVAL_ROOT ?? path.join(os.tmpdir(), `pty-corrections-${process.pid}`)
const env = { ...process.env, PTY_ROOT: root, PTY_ROOT_LEGACY_SILENT: "1" }
delete env.PTY_SESSION
delete env.PTY_SESSION_DIR

const frame = (type, payload = Buffer.alloc(0)) => {
  const header = Buffer.alloc(5)
  header.writeUInt8(type)
  header.writeUInt32BE(payload.length, 1)
  return Buffer.concat([header, payload])
}

const sizeFrame = (type, rows, columns) => {
  const payload = Buffer.alloc(4)
  payload.writeUInt16BE(rows, 0)
  payload.writeUInt16BE(columns, 2)
  return frame(type, payload)
}

const decode = (data, complete = true) => {
  const packets = []
  let offset = 0
  while (offset + 5 <= data.length) {
    const type = data.readUInt8(offset)
    const length = data.readUInt32BE(offset + 1)
    if (length > 32 * 1024 * 1024) throw new Error(`oversized packet: ${length}`)
    if (offset + 5 + length > data.length) break
    packets.push({ type, payload: data.subarray(offset + 5, offset + 5 + length) })
    offset += 5 + length
  }
  if (complete && offset !== data.length) throw new Error("truncated packet")
  return packets
}

const geometry = (packet) => ({ rows: packet.payload.readUInt16BE(0), columns: packet.payload.readUInt16BE(2) })
const exactGeometry = (value, rows, columns) => value?.rows === rows && value?.columns === columns
const roleStats = (stats) => ({
  clients: { attached: stats.clients.attached, readOnly: stats.clients.readOnly },
  terminal: { rows: stats.terminal.rows, cols: stats.terminal.cols },
})

const validateDetach = (result) => {
  assert.equal(result.code, 0, "intentional detach must exit zero")
  assert.equal(result.fdEnded, true, "machine descriptor must reach EOF")
  assert.deepEqual(result.stdout, Buffer.alloc(0), "machine stdout must stay empty")
  assert.deepEqual(result.stderr, Buffer.alloc(0), "intentional detach stderr must stay empty")
  const outcomes = result.packets.filter((packet) => OUTCOMES.has(packet.type))
  assert.equal(outcomes.length, 1, "machine stream must have exactly one terminal outcome")
  assert.equal(result.packets.at(-1)?.type, TYPE.DETACH, "DETACH must be terminal")
  assert.equal(result.packets.at(-1)?.payload.length, 0, "DETACH payload must be empty")
}

const validateTruncation = (result) => {
  assert.notEqual(result.code, 0, "truncated stream must fail")
  assert.equal(result.fdEnded, true, "truncated machine descriptor must reach EOF")
  assert.equal(result.packets.some((packet) => OUTCOMES.has(packet.type)), false, "truncation must not invent an outcome")
}

const validatePromotion = (result) => {
  assert.deepEqual(result.stats.clients, { attached: 2, readOnly: 0 })
  assert.deepEqual(result.stats.terminal, { rows: 18, cols: 60 })
  assert.equal(result.output.includes("PROMOTED_WRITABLE_7c42"), true, "promoted DATA did not reach the PTY")
  assert.equal(result.geometrySeen, true, "promoted RESIZE did not update the shared grid")
}

const validateDemotion = (result) => {
  assert.deepEqual(result.stats.clients, { attached: 1, readOnly: 1 })
  assert.deepEqual(result.stats.terminal, { rows: 30, cols: 100 })
  assert.equal(result.output.includes("DEMOTED_MUST_NOT_WRITE_7c42"), false, "demoted DATA reached the PTY")
  assert.equal(result.restoredGeometrySeen, true, "demoted client retained a grid constraint")
}

const mutate = (value, patch) => ({ ...value, ...patch })

const selfTest = () => {
  const detach = { code: 0, fdEnded: true, stdout: Buffer.alloc(0), stderr: Buffer.alloc(0), packets: [{ type: TYPE.DETACH, payload: Buffer.alloc(0) }] }
  validateDetach(detach)
  for (const bad of [
    mutate(detach, { code: 1 }),
    mutate(detach, { fdEnded: false }),
    mutate(detach, { stdout: Buffer.from("leak") }),
    mutate(detach, { packets: [] }),
    mutate(detach, { packets: [{ type: TYPE.EXIT, payload: Buffer.alloc(4) }] }),
    mutate(detach, { packets: [{ type: TYPE.DETACH, payload: Buffer.from("x") }] }),
  ]) assert.throws(() => validateDetach(bad))

  const truncation = { code: 1, fdEnded: true, packets: [{ type: TYPE.GEOMETRY, payload: Buffer.alloc(4) }, { type: TYPE.SCREEN, payload: Buffer.alloc(0) }] }
  validateTruncation(truncation)
  for (const bad of [
    mutate(truncation, { code: 0 }),
    mutate(truncation, { fdEnded: false }),
    mutate(truncation, { packets: [...truncation.packets, { type: TYPE.DETACH, payload: Buffer.alloc(0) }] }),
  ]) assert.throws(() => validateTruncation(bad))

  const promotion = {
    stats: { clients: { attached: 2, readOnly: 0 }, terminal: { rows: 18, cols: 60 } },
    output: "PROMOTED_WRITABLE_7c42\r\nANCHOR_AFTER_PROMOTION_7c42",
    geometrySeen: true,
  }
  validatePromotion(promotion)
  for (const bad of [
    mutate(promotion, { stats: { clients: { attached: 1, readOnly: 1 }, terminal: { rows: 30, cols: 100 } } }),
    mutate(promotion, { output: "ANCHOR_AFTER_PROMOTION_7c42" }),
    mutate(promotion, { geometrySeen: false }),
  ]) assert.throws(() => validatePromotion(bad))

  const demotion = {
    stats: { clients: { attached: 1, readOnly: 1 }, terminal: { rows: 30, cols: 100 } },
    output: "ANCHOR_AFTER_DEMOTION_7c42",
    restoredGeometrySeen: true,
  }
  validateDemotion(demotion)
  for (const bad of [
    mutate(demotion, { stats: { clients: { attached: 2, readOnly: 0 }, terminal: { rows: 12, cols: 40 } } }),
    mutate(demotion, { output: "DEMOTED_MUST_NOT_WRITE_7c42\r\nANCHOR_AFTER_DEMOTION_7c42" }),
    mutate(demotion, { restoredGeometrySeen: false }),
  ]) assert.throws(() => validateDemotion(bad))
  console.log("ORACLE-MUTATIONS-GREEN-7c42")
}

const runPty = (args, options = {}) => spawnSync(PTY, args, { env, encoding: "utf8", ...options })

const startSession = (name, command) => {
  const result = runPty(["run", "-d", "--id", name, "--no-display-name", "--", "sh", "-c", command])
  assert.equal(result.status, 0, result.stderr)
}

const removeSession = (name) => {
  runPty(["kill", name])
  runPty(["rm", name])
}

const timeout = (label, milliseconds = 8_000) => new Promise((_, reject) => {
  const timer = setTimeout(() => reject(new Error(`timed out: ${label}`)), milliseconds)
  timer.unref?.()
})

const collect = (stream) => {
  const chunks = []
  stream.on("data", (chunk) => chunks.push(Buffer.from(chunk)))
  return () => Buffer.concat(chunks)
}

const childResult = async (child, afterScreen) => {
  const stdout = collect(child.stdout)
  const stderr = collect(child.stderr)
  const fdChunks = []
  let fdEnded = false
  let requested = false
  child.stdio[3].on("data", (chunk) => {
    fdChunks.push(Buffer.from(chunk))
    if (!requested && decode(Buffer.concat(fdChunks), false).some((packet) => packet.type === TYPE.SCREEN)) {
      requested = true
      afterScreen(child)
    }
  })
  child.stdio[3].on("end", () => { fdEnded = true })
  const exit = new Promise((resolve) => child.once("close", (code, signal) => resolve({ code, signal })))
  const { code, signal } = await Promise.race([exit, timeout("machine attach exit")])
  const data = Buffer.concat(fdChunks)
  return { code, signal, fdEnded, stdout: stdout(), stderr: stderr(), packets: decode(data) }
}

const machineScenarios = async () => {
  const detachName = `eval-detach-${process.pid}`
  const truncName = `eval-trunc-${process.pid}`
  try {
    startSession(detachName, "printf DETACH_READY_7c42; sleep 300")
    const detached = spawn(PTY, ["attach", "--attach-stream-fd-v1", "3", detachName], { env, stdio: ["pipe", "pipe", "pipe", "pipe"] })
    const detachResult = await childResult(detached, (child) => child.stdin.write(Buffer.from([0x1c])))
    validateDetach(detachResult)
    console.log("MACHINE-DETACH-GREEN-7c42")

    startSession(truncName, "printf TRUNC_READY_7c42; sleep 300")
    const truncated = spawn(PTY, ["attach", "--attach-stream-fd-v1", "3", truncName], { env, stdio: ["pipe", "pipe", "pipe", "pipe"] })
    const truncResult = await childResult(truncated, () => {
      const killed = runPty(["kill", truncName])
      assert.equal(killed.status, 0, killed.stderr)
    })
    validateTruncation(truncResult)
    console.log("MACHINE-TRUNCATION-GREEN-7c42")
  } finally {
    removeSession(detachName)
    removeSession(truncName)
  }
}

class ProtocolSocket {
  constructor(socketPath) {
    this.socket = net.createConnection(socketPath)
    this.packets = []
    this.pending = new Set()
    this.buffer = Buffer.alloc(0)
    this.socket.on("data", (chunk) => {
      this.buffer = Buffer.concat([this.buffer, chunk])
      let offset = 0
      while (offset + 5 <= this.buffer.length) {
        const length = this.buffer.readUInt32BE(offset + 1)
        if (offset + 5 + length > this.buffer.length) break
        this.packets.push({ type: this.buffer.readUInt8(offset), payload: Buffer.from(this.buffer.subarray(offset + 5, offset + 5 + length)) })
        offset += 5 + length
      }
      this.buffer = this.buffer.subarray(offset)
      for (const check of this.pending) check()
    })
  }

  async connected() {
    if (!this.socket.connecting) return
    await Promise.race([new Promise((resolve, reject) => {
      this.socket.once("connect", resolve)
      this.socket.once("error", reject)
    }), timeout("raw socket connect")])
  }

  send(...frames) { this.socket.write(Buffer.concat(frames)) }

  async waitFor(predicate, label) {
    return this.waitForSince(0, predicate, label)
  }

  async waitForSince(index, predicate, label) {
    const found = this.packets.slice(index).find(predicate)
    if (found) return found
    let check
    const ready = new Promise((resolve) => {
      check = () => {
        const packet = this.packets.slice(index).find(predicate)
        if (!packet) return
        this.pending.delete(check)
        resolve(packet)
      }
      this.pending.add(check)
    })
    try { return await Promise.race([ready, timeout(label)]) }
    finally { this.pending.delete(check) }
  }

  async status() {
    const before = this.packets.filter((packet) => packet.type === TYPE.STATUS).length
    this.send(frame(TYPE.STATUS))
    await this.waitFor(() => this.packets.filter((packet) => packet.type === TYPE.STATUS).length > before, "STATUS response")
    return JSON.parse(this.packets.filter((packet) => packet.type === TYPE.STATUS).at(-1).payload.toString())
  }

  outputSince(index) {
    return this.packets.slice(index).filter((packet) => packet.type === TYPE.DATA || packet.type === TYPE.SCREEN).map((packet) => packet.payload.toString()).join("")
  }

  close() { this.socket.destroy() }
}

const roleScenarios = async () => {
  const name = `eval-role-${process.pid}`
  const sockets = []
  try {
    startSession(name, "exec cat")
    const socketPath = path.join(root, `${name}.sock`)
    const anchor = new ProtocolSocket(socketPath)
    sockets.push(anchor)
    await anchor.connected()
    anchor.send(sizeFrame(TYPE.ATTACH, 30, 100))
    await anchor.waitFor((packet) => packet.type === TYPE.SCREEN, "anchor baseline")

    const promoted = new ProtocolSocket(socketPath)
    sockets.push(promoted)
    await promoted.connected()
    promoted.send(frame(TYPE.PEEK, Buffer.from([0])))
    await promoted.waitFor((packet) => packet.type === TYPE.SCREEN, "PEEK baseline")
    const promotedScreens = promoted.packets.filter((packet) => packet.type === TYPE.SCREEN).length
    const promotionStart = anchor.packets.length
    promoted.send(
      sizeFrame(TYPE.ATTACH, 20, 70),
      frame(TYPE.DATA, Buffer.from("PROMOTED_WRITABLE_7c42\n")),
      sizeFrame(TYPE.RESIZE, 18, 60),
    )
    await promoted.waitFor(() => promoted.packets.filter((packet) => packet.type === TYPE.SCREEN).length > promotedScreens, "ATTACH replacement baseline")
    const promotionStats = await promoted.status()
    anchor.send(frame(TYPE.DATA, Buffer.from("ANCHOR_AFTER_PROMOTION_7c42\n")))
    await anchor.waitFor((packet) => packet.type === TYPE.DATA && packet.payload.includes(Buffer.from("ANCHOR_AFTER_PROMOTION_7c42")), "promotion output barrier")
    const promotionOutput = anchor.outputSince(promotionStart)
    const promotionGeometry = anchor.packets.slice(promotionStart).filter((packet) => packet.type === TYPE.GEOMETRY).map(geometry)
    validatePromotion({
      stats: roleStats(promotionStats),
      output: promotionOutput,
      geometrySeen: promotionGeometry.some((value) => exactGeometry(value, 18, 60)),
    })
    console.log("ROLE-PROMOTION-GREEN-7c42")
    const restoreStart = anchor.packets.length
    promoted.close()
    await anchor.waitForSince(restoreStart, (packet) => packet.type === TYPE.GEOMETRY && exactGeometry(geometry(packet), 30, 100), "grid restore after promoted client closes")

    const demoted = new ProtocolSocket(socketPath)
    sockets.push(demoted)
    await demoted.connected()
    demoted.send(sizeFrame(TYPE.ATTACH, 20, 70))
    await demoted.waitFor((packet) => packet.type === TYPE.SCREEN, "ATTACH baseline")
    const demotedScreens = demoted.packets.filter((packet) => packet.type === TYPE.SCREEN).length
    const demotionStart = anchor.packets.length
    demoted.send(frame(TYPE.PEEK, Buffer.from([0])))
    await demoted.waitFor(() => demoted.packets.filter((packet) => packet.type === TYPE.SCREEN).length > demotedScreens, "PEEK replacement baseline")
    demoted.send(
      sizeFrame(TYPE.RESIZE, 12, 40),
      frame(TYPE.DATA, Buffer.from("DEMOTED_MUST_NOT_WRITE_7c42\n")),
    )
    const demotionStats = await demoted.status()
    anchor.send(frame(TYPE.DATA, Buffer.from("ANCHOR_AFTER_DEMOTION_7c42\n")))
    await anchor.waitFor((packet) => packet.type === TYPE.DATA && packet.payload.includes(Buffer.from("ANCHOR_AFTER_DEMOTION_7c42")), "demotion output barrier")
    const demotionOutput = anchor.outputSince(demotionStart)
    const demotionGeometry = anchor.packets.slice(demotionStart).filter((packet) => packet.type === TYPE.GEOMETRY).map(geometry)
    validateDemotion({
      stats: roleStats(demotionStats),
      output: demotionOutput,
      restoredGeometrySeen: demotionGeometry.some((value) => exactGeometry(value, 30, 100)),
    })
    console.log("ROLE-DEMOTION-GREEN-7c42")
  } finally {
    for (const socket of sockets) socket.close()
    removeSession(name)
  }
}

if (process.argv[2] === "--self-test") {
  selfTest()
} else {
  fs.mkdirSync(root, { recursive: true })
  try {
    if (process.argv[2] !== "--roles-only") await machineScenarios()
    if (process.argv[2] !== "--machine-only") await roleScenarios()
    const remaining = runPty(["list", "--json"])
    assert.equal(remaining.status, 0, remaining.stderr)
    assert.deepEqual(JSON.parse(remaining.stdout), [])
    console.log("ATTACH-CORRECTIONS-CLEANUP-GREEN-7c42")
  } finally {
    fs.rmSync(root, { recursive: true, force: true })
  }
}
