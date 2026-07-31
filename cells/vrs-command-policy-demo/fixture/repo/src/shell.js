// Parse only the first simple command. This is a data parser, not a shell.
export function firstCommandArgv(command) {
  if (typeof command !== "string") {
    throw new TypeError("command must be a string");
  }

  const argv = [];
  let word = "";
  let started = false;
  let quote = null;

  const push = () => {
    if (started) {
      argv.push(word);
      word = "";
      started = false;
    }
  };

  for (let index = 0; index < command.length; index += 1) {
    const char = command[index];

    if (quote === "'") {
      if (char === "'") quote = null;
      else word += char;
      started = true;
      continue;
    }

    if (quote === '"') {
      if (char === '"') {
        quote = null;
      } else if (char === "\\") {
        index += 1;
        if (index >= command.length) throw new Error("trailing escape");
        word += command[index];
      } else {
        word += char;
      }
      started = true;
      continue;
    }

    if (char === "'" || char === '"') {
      quote = char;
      started = true;
      continue;
    }
    if (char === "\\") {
      index += 1;
      if (index >= command.length) throw new Error("trailing escape");
      word += command[index];
      started = true;
      continue;
    }
    if (char === ";" || char === "\n" || char === "|" || char === "&") {
      push();
      break;
    }
    if (/\s/.test(char)) {
      push();
      continue;
    }
    word += char;
    started = true;
  }

  if (quote !== null) throw new Error("unterminated quote");
  push();
  return argv;
}

export function quoteShellWord(value) {
  if (typeof value !== "string") throw new TypeError("shell word must be a string");
  if (/^[A-Za-z0-9_./:@%+=,-]+$/.test(value)) return value;
  return `'${value.replaceAll("'", `'\"'\"'`)}'`;
}
