# Orbit launch catalog

This package builds and validates declarative task records for the Orbit
launcher. A record can contain:

- `id`: stable task identifier;
- `kind`: task class such as `worker` or `helper`;
- `active`: whether the declaration participates in the current catalog;
- `workspace`: optional workspace string;
- `command`: an untrusted shell command string.

`buildWorkerTask()` produces the common active worker shape.
`validateCatalog()` returns `{ ok, errors }` and never launches configured
commands.

```sh
npm test
npm run example
```
