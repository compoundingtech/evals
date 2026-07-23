// A tiny in-memory task store. Tasks are { id, title, done }. Ids are assigned sequentially.
export function createStore(seed = []) {
  const tasks = seed.map((t) => ({ ...t }));
  let seq = tasks.reduce((m, t) => Math.max(m, t.id), 0);
  return {
    all: () => tasks,
    find: (id) => tasks.find((t) => t.id === id),
    insert: ({ title }) => {
      const task = { id: ++seq, title, done: false };
      tasks.push(task);
      return task;
    },
  };
}
