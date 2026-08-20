# pi-native-delivery — the pi harness's native-delivery contract

**What it evaluates.** st2 gained `pi` as a third harness, and unlike Codex and Claude a pi seat is
delivered to *natively*: st2 injects a channel extension into the live pi process and hands messages
to `pi.sendUserMessage()`, so nothing inspects the terminal. This cell pins the deterministic half of
that contract — the parts that must hold before any model is involved.

**Model-free on purpose.** Every claim here is decidable without a model seat, a pi binary, or a
network, so it belongs in the always-runnable tier rather than behind a paid launch. What it does
*not* cover is the model-dependent half — whether a real agent restores context, drains its inbox,
and takes a mid-turn steer. Those were measured by hand against a live provider and are recorded in
st2 at `docs/vrs/.experiments/2026-08-18-pi-captures/run-h-live-provider.txt`; turning them into a
model-backed cell needs corpus policy work that this cell deliberately does not smuggle in (see
"Not covered" below).

**Run it:** `st2 eval ./cells/pi-native-delivery/`

## What each judge holds

| Judge | Why it exists |
|---|---|
| `EXPANSION` | The declaration must not name the channel extension — `st2 driver pi-session` splices it in from the binary's *verified* hook set, so a catalog never pins one host's layout. Also asserts `-a`, since pi's project-trust modal otherwise blocks startup before any event fires, and that `effort` lowers to pi's `--thinking`. |
| `EXCLUSIVITY` | A declaration carrying both `ding` and `deliver` must fail closed. This is the rule that keeps a natively-delivered seat off the PTY write path entirely, which is what leaves decision `0004`'s synchronous-proof gate untouched. |
| `TRANSPORT` | The hand-authored `deliver "pi-channel"` form must reach the *same wrapper* as the typed driver, and generate **no DING companion**. Both paths are compiled for real and their launched command lines compared byte-for-byte after masking the catalog path — the inventory does not expose argv, and a substring check would not catch a divergent identity, runtime id, or provider argv. |
| `HOOKSET` | pi has no hook mechanism of its own, so its extension ships in the same immutable, content-addressed set as the Codex and Claude lifecycle scripts. |
| `FAIL-CLOSED` | Without a verified set the wrapper cannot supply the channel, so the launch is **held** and the error names the remedy — rather than flapping and burying that message in a restart loop. |
| `CONTRACT` | The restored boot ritual is a *pointer* into st2's shipped bus contract, not a standalone instruction: it says to set status and drain the inbox without naming the commands. The declaration must therefore land that contract at `AGENTS.md`, where pi reads it, byte-identically. A fixture stand-in is used rather than vendoring st2's template across repos. Measured live: without the contract a real model hunts the filesystem with `find /` and never sets its status. |

## Teeth

Verified non-vacuous rather than assumed, three ways.

- **Whole cell against a predecessor.** Run against an `st2` predating pi support, all seven gating
  judges fail; against merged `main`, all seven pass. A green result is evidence about st2, not
  about the cell being generous.
- **`TRANSPORT` against a divergent wrapper.** The judge claims the two declaration paths converge,
  so it is probed with a mutation that makes them diverge: switch the hand-authored fixture to
  `deliver "mcp"` with a `claude` argv. The judge fails and names the wrapper it actually got —
  `driver claude-session` — rather than passing on the absence of a DING companion.
- **Against a variant that never launched.** `ABSENT` is rejected explicitly, so a comparison
  between two failures cannot register as agreement.

The `TRANSPORT` probe matters because the judge's first version was genuinely weak: it asserted only
that the task inventory lacked `ding` and mentioned the agent, which a wrong wrapper would satisfy.
The task inventory does not expose argv, so the current judge compiles both declaration paths for
real and compares the launched command lines after masking the catalog path.

## Not covered, and why

A model-backed pi cell is not simply a new directory. The corpus pins providers through
`bin/check-model-policy.sh`, whose provider set is closed over `(claude|codex)`; there are
`check-claude-native.sh` and `check-codex-native.sh` siblings with no pi equivalent; and the catalog
states that every bus-connected model seat is mechanically checked for the **event-first DING
lifecycle**, which a natively-delivered pi seat does not and must not have. Adding one means
extending those policies deliberately — a corpus decision, not a side effect of adding a cell.
