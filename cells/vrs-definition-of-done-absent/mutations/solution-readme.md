# health report slice

This package contains small helpers for health-check reports. Governing material, when supplied with the
repository, lives under `docs/governance/`.

Run the test suite with:

```sh
npm test
```

Summarize a JSON file of health checks with:

```sh
health-summary checks.json
```

The command exits 0 when every check passes and exits 2 when one or more checks fail.

