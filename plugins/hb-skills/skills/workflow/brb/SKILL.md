---
name: brb
description: "Timed work session. Triggers: user says 'brb', 'back in X mins/hrs', 'work for X mins', or similar where user stepping away and want continued independent work for a specified duration. User gives a duration and expects you to work continuously on the current task for that entire period, checking the clock to ensure it doesn't stop early."
---

If duration = null:
if calendar tools available: check for next free slot; else ask;

If task = unclear: ask;

## Perform

1. Record current time as start, calculate end time.
2. Start working on the current task continuously.
3. Chain steps: finish → review → improve → next piece → repeat.
4. Every time you think you are done, check the time. Before end time — keep going. At or past end time — stop and summarise.

## Do

- Treat duration as a min — overshoot is fine, undershoot never
- Be ambitious — build, test, fix, polish, extend
- Note blockers, skip them, keep working on what you can
- Check the clock on work stage change
- On each work stage change, if `.scratch/decisions.md` exists, recheck its `Assumes` column the same way `/go` does.
- When primary work runs dry: review, add tests/docs, anticipate next steps, clean up

## Don't

- Stop before end time for any reason
- Do only one thing and wait
- Wander off-task

## Summary template (at conclusion)

```
Work Summary: {Time start} - {Time End}

| Item | Time | Done | Decisions | Blocked |
|------|------|------|-----------|---------|

⚠ Assumptions now in doubt
<any ledger rows whose Assumes clause is now broken or suspect — omit if none>

Responses are short, tight and succinct.

**Next steps:**

```
