function validateRecord(record, context) {
  if (record === null || typeof record !== "object" || Array.isArray(record)) {
    throw new TypeError(`${context}: expected an object record`);
  }

  for (const field of ["run_id", "cell", "result"]) {
    if (typeof record[field] !== "string" || record[field].length === 0) {
      throw new TypeError(`${context}: missing non-empty ${field}`);
    }
  }

  if (record.result !== "PASS" && record.result !== "FAIL") {
    throw new TypeError(
      `${context}: unknown result ${record.result} for ${record.run_id}`,
    );
  }
}

function validateUnique(records, contextForIndex) {
  const seen = new Set();
  records.forEach((record, index) => {
    const context = contextForIndex(index);
    validateRecord(record, context);
    if (seen.has(record.run_id)) {
      throw new TypeError(`${context}: duplicate run_id ${record.run_id}`);
    }
    seen.add(record.run_id);
  });
}

export function parseJsonLines(text) {
  const records = [];
  const sourceLines = text.split("\n");

  sourceLines.forEach((line, index) => {
    if (line.trim().length === 0) {
      return;
    }

    let record;
    try {
      record = JSON.parse(line);
    } catch {
      throw new TypeError(`line ${index + 1}: malformed JSON`);
    }
    records.push({ record, lineNumber: index + 1 });
  });

  validateUnique(
    records.map(({ record }) => record),
    (index) => `line ${records[index].lineNumber}`,
  );
  return records.map(({ record }) => record);
}

export function summarize(records) {
  validateUnique(records, (index) => `record ${index + 1}`);

  const byCell = new Map();
  for (const record of records) {
    const current = byCell.get(record.cell) ?? {
      cell: record.cell,
      accepted_pass: null,
      last_run: null,
    };
    if (record.result === "PASS") {
      current.accepted_pass = { ...record };
    }
    current.last_run = { ...record };
    byCell.set(record.cell, current);
  }

  return [...byCell.values()].sort((left, right) =>
    left.cell.localeCompare(right.cell),
  );
}
