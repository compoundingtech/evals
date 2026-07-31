import { appendFileSync } from "node:fs";

const receivedPath = process.argv[2];
if (!receivedPath) throw new Error("received-byte path is required");

process.stdin.setRawMode?.(true);
process.stdin.resume();
process.stdin.on("data", (chunk) => appendFileSync(receivedPath, chunk));
process.stdout.write("DING-AB-READY\r\n");

const timer = setInterval(() => {}, 1000);
function stop() {
  clearInterval(timer);
  process.exit(0);
}

process.on("SIGTERM", stop);
process.on("SIGINT", stop);
