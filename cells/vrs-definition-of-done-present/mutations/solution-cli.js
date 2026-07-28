#!/usr/bin/env node
import fs from "node:fs";

import { summarizeChecks } from "../src/summary.js";

const file = process.argv[2];
if (!file) {
  console.error("usage: health-summary FILE");
  process.exit(1);
}

const checks = JSON.parse(fs.readFileSync(file, "utf8"));
const summary = summarizeChecks(checks);
process.stdout.write(`${JSON.stringify(summary)}\n`);
process.exitCode = summary.failing === 0 ? 0 : 2;

