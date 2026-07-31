process.stdin.setRawMode?.(true);
process.stdin.resume();
process.stdout.write("\u001b[?1049hACTIVITY-LEASE-READY\r\n");

const timer = setInterval(() => {}, 1000);
function stop() {
  clearInterval(timer);
  process.stdout.write("\u001b[?1049l");
  process.exit(0);
}

process.on("SIGTERM", stop);
process.on("SIGINT", stop);
