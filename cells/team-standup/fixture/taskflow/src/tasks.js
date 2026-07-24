// taskflow — a tiny in-memory task store (the SaaS backend's core).
let seq = 0;
const tasks = [];

export function addTask(title) {
  if (typeof title !== "string" || title.trim() === "") throw new TypeError("title required");
  const t = { id: ++seq, title, done: false };
  tasks.push(t);
  return t;
}

export function listTasks() {
  return tasks.map((t) => ({ ...t }));
}
