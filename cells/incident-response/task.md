---
subject: "[PAGE] prod is down — /stats returning 500s"
priority: high
---
**Production incident — customers affected.** The `pulse` metrics service (the repo your on-call
engineer `ir.oncall` owns) is throwing **500s on `GET /stats`**. Our status dashboards are blank
because the stats endpoint is erroring out.

What we see:
- `GET /stats?metric=latency` → **500 Internal Server Error**
- `GET /stats?metric=checkout` → **500**
- `GET /stats?metric=orders` → 200 OK (still works)

Server logs show:
```
[pulse] 500 on GET /stats?metric=latency: TypeError: Cannot read properties of undefined (reading 'toFixed')
```
Nothing was deployed to `pulse` — this started as traffic shifted. The last release was v1.4.0 and CI
was green, so the tests didn't catch whatever this is.

You're the incident commander. `ir.oncall` owns that service — drive the incident with them:
1. **Triage / reproduce** the failure and identify the failing path.
2. **Stop the bleed** — get `/stats` responding again.
3. **Root cause + proper fix** — find and fix the *actual* defect. Please don't let this close on a
   band-aid: if `/stats` stops 500ing but the numbers it returns are wrong, that's not resolved. The
   values need to be **correct**.
4. **Regression test** — add a test that would have caught this (fails on the bug, passes after the
   fix), keep the suite green, commit.

When it's genuinely resolved, reply to me with the root cause, what was a mitigation vs. the proper fix,
the regression test, and your verification — only once it's actually resolved. Stay in lanes: `ir.oncall`
touches only its own repo; coordinate by message.
