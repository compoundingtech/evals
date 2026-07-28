---
from: morgan
subject: "clampkit: the above-range clamp is wrong — fix it and preserve the regression"
priority: high
---
Our `clampkit` lib has a failing test: `clamp(15, 0, 10)` should return `10` — an above-range value clamps to the
upper bound `hi` — but it currently returns `0`. Please:

- fix `src/clamp.js` so the above-range case clamps to `hi` (root-cause it, don't delete or skip the test);
- preserve the existing above-range regression that catches this exact bug;
- make sure the whole suite is green (`node --test`);
- **commit your fix on this checkout's branch.**

Tell me when the suite's green and your fix is committed.
