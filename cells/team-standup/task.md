---
from: jordan
subject: "need completeTask(id) in taskflow — stand up someone to own it"
priority: high
---
Hey — small but real one for the `taskflow` backend. We need a `completeTask(id)` function:

- it marks the task with that id as **done** and **returns the updated task**, and
- it **throws** if the id doesn't exist — no silent no-op.

Add it to the `taskflow` repo with a test that would catch a regression, and keep the suite green.

I don't want you touching the code yourself — **stand up someone to OWN `taskflow`** and drive it through.
Tell me how you split it, and confirm back when it's green.
