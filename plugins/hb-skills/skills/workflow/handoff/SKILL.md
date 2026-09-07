---
name: handoff
description: "Package work-in-progress for a later session or another agent. Triggers: '/handoff', 'hand this off', 'write up where we are', 'I need to stop', runway expiring in /go or /brb with significant work remaining, or context getting long enough that a fresh session would be cheaper. Produces a single handoff brief that carries the decision ledger forward intact."
---

# Handoff

Package the current state of work so a later session — same person, different day, or a different agent — can continue without re-deriving why anything was done.

## When to run it

- Runway expired with work left
- Context is bloated — a fresh session would be cheaper than continuing
- Switching agents or people
- End of day on multi-day work

## Output: `.scratch/handoff.md`

```markdown
⚠ Read "Assumptions to verify first" before building anything on top of this handoff.

# Handoff — <task, one line> — <date/time>

## State
<what exists now, how to run/see it, what's known broken — 3–6 lines>

## Decision ledger
<the full table from .scratch/decisions.md, verbatim. ⚠ rows first. Do not summarise it into prose.>

## Next
<ordered punch list of what to do next, each line one sentence describing what exists when done>

## Assumptions to verify first
<every ledger row whose Assumes clause hasn't been confirmed, or is marked ⚠. The next session checks these before building anything on top of them.>

## Do not re-solve
<what was considered and ruled out, and why — so it isn't re-derived at the wrong size. Pull from ledger rows and from /route or /grill summaries if they exist.>
```

## Rules

- The ledger is copied, never paraphrased. Losing a row loses the reason.
- If `.scratch/decisions.md` doesn't exist, reconstruct the ledger from the session before writing the handoff, using the `/call` format. Note at the top of the ledger that it was reconstructed.
- Do not write a narrative of the session. State, ledger, next, verify, ruled-out. Nothing else.
- A fresh session picking this up should read "Assumptions to verify first" before anything else. Say so at the top of the file.

## Resuming

When a session starts and `.scratch/handoff.md` exists, read it, verify the "Assumptions to verify first" section, mark rows ✓ or ⚠ in the ledger, then continue from "Next".
