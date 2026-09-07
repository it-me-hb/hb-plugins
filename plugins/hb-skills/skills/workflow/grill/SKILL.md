---
name: grill
description: "Stress-test a plan or design with focused questions. Triggers: 'grill me', 'poke holes', 'what am I missing', 'stress test this'. One question at a time, recommend an answer with each, cap at 10 rounds."
---

# Grill

Interview the user about a plan or design to find gaps before building starts.

## Rules

1. **One question at a time.** Ask, wait, respond. Multiple questions in one message is overwhelming.
2. **Lead with your recommendation.** Every question comes with what you'd pick and a one-sentence reason. The user confirms, overrides, or discusses — then you move on.
3. **Explore before asking.** If a question can be answered by reading the codebase, read the codebase instead of asking. Only surface questions that need a human judgment call.
4. **Walk the dependency tree.** Start from the highest-leverage decision and follow the branches down. Resolve upstream choices before asking about downstream ones that depend on them.
5. **Cap at 10 rounds.** After 10 questions (or when you run out of genuine uncertainty), stop and summarise what was decided. If the plan still has holes, say which ones and why you couldn't resolve them.

## Summary (at conclusion)

```markdown
## Decisions

| # | Question | Decision | Assumes | Notes |
|---|----------|----------|---------|-------|

If this feeds into /go, seed `.scratch/decisions.md` from this table.

## Open items
<anything unresolved — blocked on external info, needs prototyping to answer, or user deferred>

## Ready for
<which skill to go to next: /scope if it needs decomposition, /go if it's ready to build>
```
