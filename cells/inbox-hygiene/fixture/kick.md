<!-- Hermetic kick: one message carrying a distinctive TOKEN. spin.sh strips this header + stamps a
     boot-time filename so the boot ritual ACTS on it. The SAME message is later re-delivered (un-archived)
     by inject-restart.sh to test the resume double-act guard. -->
---
from: requester
subject: "process this item"
---
Please process this work item. Record that you handled it.

TOKEN: __IH_TOKEN__

Once recorded, you are done with this item — do not do it more than once.
