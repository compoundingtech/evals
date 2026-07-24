# tasklit

A tiny task-command library. Commands live in `src/commands/` and are dispatched by name.

```js
import { createStore } from "./src/store.js";
import { dispatch } from "./src/commands/index.js";

const store = createStore();
dispatch("add", { title: "buy milk" }, store); // { ok: true, value: { id: 1, title: "buy milk", done: false } }
dispatch("done", { id: 1 }, store);            // { ok: true, value: { id: 1, title: "buy milk", done: true } }
dispatch("list", {}, store);                   // { ok: true, value: [ ... ] }
```

Available commands: `add`, `list`, `done`, `remove`. Run the tests with `npm test`.
