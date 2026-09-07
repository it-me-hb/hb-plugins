---
name: call
description: Autonomous decision-making at a fork. Enumerate 2-4 options, score value/effort/reversibility/dependencies, pick, log reasoning, move on. Use at any decision point — design, architecture, priority, approach — especially in AFK or autonomous mode where blocking on the human is not an option.
---

# Call

A **call** is a decision made and moved past. The grilling skill fans out the full decision tree and waits for the human at every frontier. This skill collapses the tree: pick the branch, log why, keep building.

## When to call

Any time forward motion is blocked by a choice with more than one reasonable path. Not for surfacing requirements (that's grilling) — for choosing between known options, now.

## The framework

### 1. Frame
One sentence: what's being decided and why it's blocking.

### 2. Options
2-4 viable paths. Each is one line: what it is and what it delivers. If you see more than 4, the obviously dominated ones haven't been cut yet.

### 3. Score
Quick read on four axes — directional, not numeric:

- **Value**: what does this deliver or unblock?
- **Effort**: time, complexity, getting-stuck risk
- **Reversibility**: undo cost — minutes, hours, days, or never
- **Dependency weight**: what's waiting on this decision?

### 4. Pick
Name the winner. One sentence: which axis tipped it.

### 5. Log
Append to the decision log (the human's review surface when they return).

## Speed calibration

**Reversibility sets the clock.** The harder a call is to undo, the more deliberation it earns:

- **Trivially reversible** (file structure, naming, local config): decide in seconds. Don't invoke the full framework — just pick and note it.
- **Cheaply reversible** (internal architecture, tool choice, library pick): one minute. Quick mental pass through the axes.
- **Expensive to reverse** (schema shape, public API surface, data migration strategy): full framework. All five steps, written out.
- **Irreversible** (deleting user data, pushing to prod, sending external comms): full framework **plus** block for human confirmation, even in AFK mode.

**Ties break on dependency weight.** The option that unblocks more downstream work wins over the locally optimal choice.

**Deferral is not a call.** "We'll decide later" is valid only when nothing is blocked by the decision. If work is waiting, pick now with what you know. A wrong call you can reverse costs less than an unmade call that stalls everything behind it.

## Decision log format

```
| # | Decision | Picked | Why | Rev? |
|---|----------|--------|-----|------|
| 1 | State management | Zustand | Lightest, covers needs, easy to swap | min |
| 2 | Auth strategy | Session-based | Simpler for prototype, JWT overhead not justified | hrs |
| 3 | Event schema | Flat table | Query patterns are simple; normalize if they get complex | days |
```

Rev? = undo cost shorthand: min / hrs / days / never.
