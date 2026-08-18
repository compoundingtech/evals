# st2 bus instructions (fixture stand-in)

A minimal stand-in for st2's shipped `templates/bus.st2.md`. The cell asserts that whatever the
declaration names as its contract asset arrives at `AGENTS.md` byte-identically, which is what makes
the restored boot ritual's commands reachable. It deliberately does not vendor st2's real template:
duplicating another repo's document here would rot, and the fidelity of `copy` is st2's to test.

## Boot ritual

1. `st2 status $ST_AGENT --set available`
2. `st2 message ls`, then per message `st2 message read <filename>` and `st2 message archive <filename>`
3. `st2 agents --json --enrich`
