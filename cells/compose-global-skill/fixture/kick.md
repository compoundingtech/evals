<!-- Hermetic kick (positive): asks a DOMAIN question whose answer lives ONLY in a global skill's body. It names
     the domain, NEVER the answer string — so a correct answer can only come from loading the GLOBAL skill through
     the compose, not from the kick. spin.sh substitutes {{DOMAIN}} from $SB/.stev/domain. -->
---
from: requester
subject: "global-skill check"
---
Quick question, using whatever skills are available to you (including any user/global-level skills you have):

**What is {{DOMAIN}}?**

Answer with ONLY that exact name/value (a single token, nothing else), and **write it to a file named
`GLOBAL_SKILL.txt`** in your current working directory. Use only what your available skills tell you — do not guess.
If you have no skill that answers this, write nothing and reply saying so. When `GLOBAL_SKILL.txt` is written,
reply that the check is done.
