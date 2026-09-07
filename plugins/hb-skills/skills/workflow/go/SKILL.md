---
name: go
description: "Ambitious, timeboxed execution. Triggers on: ambition signals ('build this in 20 minutes', 'ship it', 'prototype this now'), or explicit /go. Collapses plan-spec-build into forward motion, uses /call at decision points, produces a return brief when done."
---

# Go

The operating mode for ambitious, autonomous execution. Default agent disposition is cautious: plan, ask, spec, then build. **Go** flips it: build the thing, refine as you go, ship what works. A working artifact you can react to beats a document you can read about one.

## Activation

Go needs a **task** and optionally a **runway**:

- **Task + ambition**: "I want a working prototype in 20 minutes"
- **Explicit**: `/go <task description>`

A task without a runway defaults to the current session.

## The posture

Not steps — operating principles for the duration:

**1. Prototype fidelity, production direction.** Build toward the real thing at prototype speed. Skip polish, skip edge cases, skip tests unless they help you think. The goal is a working artifact the user can touch.

**2. Make calls, don't ask.** At every decision point, apply the `/call` framework. Score, pick, log, move. The decision log is the user's review surface — they check reasoning after the fact, not before. Exception: irreversible actions affecting shared systems (production deploys, external communications, data deletion) still block for confirmation.

**3. Spine first.** The **spine** is the thinnest vertical slice that makes the whole deliverable work end to end. Build it first. Then widen — add features, handle edges, improve UX — in order of value, until the runway expires or the work is done.

**4. Scope to the runway.** Calibrate ambition to the time available:
- **20 min**: one focused deliverable, one critical path, zero detours
- **1-2 hrs**: a working feature with multiple connected parts
- **4-8 hrs**: a small product or a significant system change
- **No runway**: current session's worth of aggressive progress

If the work outgrows the runway, cut scope from the edges to protect the spine. A working thing with fewer features beats a broken thing with all of them.

**5. Log as you go.** Every call, every milestone, every pivot. The return brief assembles itself from these breadcrumbs.

## Execution

### 1. Quick plan (< 5 min)

A **punch list**, not a spec: the critical path from nothing to a working deliverable. Each line is one sentence describing what exists when the step is done.

If **/scope** has already been run for this work, the diagram is the plan — skip re-planning what's already decomposed:
- The main flow is the spine
- Subgraphs are branches to widen into
- Open questions feed into /call for resolution before building starts

Otherwise: identify the spine yourself. Map dependencies. Number the sequence. This plan lives in your working context — write it to `.scratch/go-plan.md` only if the user needs to see progress.

Call the Skill tool with "call" to load the decision framework. Apply it at every fork from here on without reloading.

### 2. Work the punch list

Execute in sequence. At each step:

- **Decision needed?** Apply the call framework — frame, score, pick, log, move.
- **Research needed?** Research inline if under ~2 min; otherwise make a call, log it as "assumed — verify later."
- **Harder than expected?** Re-scope. Cut from later steps to protect the spine.
- **Easier than expected?** Pull the next high-value item forward.

### 3. Checkpoints

At natural breakpoints — a step complete, a significant call made, a pivot — log:
- What's done
- What's next
- Calls since last checkpoint
- Runway remaining vs work remaining
- **Recheck the ledger.** Re-read the `Assumes` column in `.scratch/decisions.md`. If anything you've learned since makes an assumption false, mark that row `⚠ broken`, then walk `Depends on` forward and mark every row that transitively depends on it `⚠ suspect`. Fix what you can now; the rest goes in the return brief.

### 4. Return brief

When the work is done or the runway expires:

```markdown
## What was built
<one paragraph: what exists now, how to see/run it>

## Calls made
<the decision ledger table, copied from .scratch/decisions.md. Any row marked ⚠ goes at the top.>

## What's left
<descoped items, deferred decisions, "verify later" assumptions>
<any ⚠ suspect rows not yet re-verified>

## Look at these
<2-3 things worth the user's attention: a judgment call that could go either way, a shortcut worth revisiting, something that works but feels off>
```

Optimised for a human returning: readable in 2 minutes, full picture of where things stand.

## Composing with other skills

Go is a wrapper around whatever the work requires:

- `/scope` upstream if the work needs decomposition before building — but don't scope what you can just build
- `/call` at every decision point (loaded once at session start). The ledger it writes is the spine of the return brief and the handoff.
- `/handoff` if the runway expires and significant work remains
