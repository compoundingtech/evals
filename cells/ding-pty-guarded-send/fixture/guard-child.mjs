import { appendFileSync } from "node:fs";

const receivedPath = process.argv[2];
if (!receivedPath) throw new Error("received-byte path is required");

process.stdin.setRawMode?.(true);
process.stdin.resume();
process.stdin.on("data", (chunk) => appendFileSync(receivedPath, chunk));
process.on("SIGUSR1", () => process.stdout.write("OUTPUT-RACE\r\n"));
process.stdout.write("GUARDED-SEND-READY\r\n");

const timer = setInterval(() => {}, 1000);
function stop() {
  clearInterval(timer);
  process.exit(0);
}

process.on("SIGTERM", stop);
process.on("SIGINT", stop);
