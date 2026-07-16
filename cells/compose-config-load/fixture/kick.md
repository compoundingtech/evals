<!-- Hermetic kick: triggers the compose-config-load check. spin.sh strips this header + stamps a boot-time
     filename so the boot ritual acts on it. It names NO tokens and NO secret/greeting values — the worker can
     only do the task by loading its own repo CLAUDE.md (for the secret) + its project greet skill (for the
     greeting) through the compose. -->
---
from: requester
subject: "compose-config-load check"
---
Please do these two things in your repo now, then reply on this thread that you are done:

1. Your repo's own instructions (its CLAUDE.md) define a **secret**. Following those instructions, **write the
   secret to a file named `SECRET.txt`** in your current working directory (the exact secret value, nothing else).

2. Use your **greet** skill to produce the greeting, and **write the greeting to a file named `GREET.txt`** in your
   current working directory (the exact greeting value, nothing else).

Do not guess or invent either value — use only what your own CLAUDE.md and your greet skill tell you. When both
files are written, reply that the check is done.
