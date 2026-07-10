<!-- Hermetic kick: triggers the skill-inheritance check. spin.sh strips this header + stamps a boot-time
     filename so the boot ritual acts on it. It deliberately names NO tokens and NO sentinel filenames — the
     worker can only do the work by invoking the skills it actually inherited (their bodies carry the secret). -->
---
from: requester
subject: "run the eval skill-inheritance check"
---
Please run the **eval skill-inheritance check** now.

Invoke every skill available to you whose name contains `evalskill` (they may appear as a bare name like
`evalskill-project` or under a plugin namespace like `evalpkg:evalskill-plugin`) and follow each skill's
instructions exactly. Invoke all of them — do not skip any, and do not fabricate the effect of any skill you
do not actually have.

When you have invoked each available skill and followed its instructions, reply on this thread that the
check is done and list which skills you were able to invoke.
