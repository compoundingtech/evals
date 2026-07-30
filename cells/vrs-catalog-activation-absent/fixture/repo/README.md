# Harbor catalog reconciler

Harbor stages one signed candidate per host under
`incoming/<host>/candidate.json`, activates a validated catalog through the
store module, then reconciles its service names into a file-backed registry.
The registry models service identity and controller ownership without starting
real processes.

The public API is exported from `src/index.js`:

- `makeCandidate({ host, version, services, complete })`
- `loadActive(root, host)`
- `activateCandidate(root, host, options?)`
- `convergeHost({ root, host, catalog, controllerId })`
- `refreshAndConverge(options)`

`refreshAndConverge` accepts `peerReachable`, `explicitPeerDependency`, and an
optional `afterStage` fault-injection callback. It returns local activation,
health, catalog, and service-action evidence.

```sh
npm test
```
