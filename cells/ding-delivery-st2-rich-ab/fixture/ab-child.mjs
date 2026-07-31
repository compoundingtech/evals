import { appendFileSync } from "node:fs";

const receivedPath = process.argv[2];
if (!receivedPath) throw new Error("received-byte path is required");

process.stdin.setRawMode?.(true);
process.stdin.resume();
let pending = "";
process.stdin.on("data", (chunk) => {
  appendFileSync(receivedPath, chunk);
  pending += chunk.toString("utf8");
  for (;;) {
    const match = pending.match(/\u001b\[200~([\s\S]*?)\u001b\[201~[\r\n]/);
    if (!match) break;
    pending = pending.slice(match.index + match[0].length);
    const notice = match[1];
    process.stdout.write(
      `Messages to be submitted after next tool call:\r\n${notice}\r\n\r\n` +
      "\u001b[1m›\u001b[1C\u001b[22;2mReady\r\n\r\n" +
      "  \u001b[0mgpt-5.6-sol xhigh · /workspace\r\n",
    );
  }
});
process.stdout.write("ST2-RICH-AB-READY\r\n");

const timer = setInterval(() => {}, 1000);
function stop() {
  clearInterval(timer);
  process.exit(0);
}

process.on("SIGTERM", stop);
process.on("SIGINT", stop);
