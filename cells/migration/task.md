---
subject: "upgrade greetkit 1.0.0 -> 2.0.0 in meeting-notes (breaking release)"
priority: high
---
Our `meeting-notes` app (the repo your specialist `mig.dev` owns) depends on the vendored **greetkit**
library, currently **1.0.0**. greetkit **2.0.0** just shipped and it's a **breaking** release. Please get
us onto it.

The 2.0.0 source and its list of breaking changes are already in the repo at `lib/greetkit-2.0.0/`
(see `lib/greetkit-2.0.0/CHANGELOG.md`). We want to be fully on 2.0.0 — not pinned to the old version.

You're the supervisor: `mig.dev` owns that repo — delegate this to it. Ask it to:
1. **Upgrade** the vendored greetkit dependency from 1.0.0 to 2.0.0 (adopt the 2.0.0 source).
2. **Fix every call site** affected by the breaking changes — don't miss any; the suite will tell you.
3. **Don't silently drop functionality.** Where 2.0.0 *removes* something the app used, keep the app's
   behavior by reimplementing it with what 2.0.0 provides — don't just delete the feature (or its test).
4. **Keep the suite green** (`npm test`). Update tests where the behavior genuinely changed, but **don't
   weaken** them (no skipping/removing tests or loosening assertions just to pass).
5. **Commit**, and report back what changed for each breaking change, how any removed capability was
   preserved, the files + commit, and the verification.

Verify read-only when it reports done — greetkit is really 2.0.0, no old-API references linger, nothing
was silently dropped, and the suite is green without weakened tests — then reply to me with what changed
and your verification, only once it's done and verified. Stay in lanes: `mig.dev` touches only its own
repo; coordinate by message.
