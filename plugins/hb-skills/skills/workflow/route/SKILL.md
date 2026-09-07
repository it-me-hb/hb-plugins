---
name: route
description: Work out the smallest thing that actually solves a problem, before building it. Use when a problem is vague, sounds hard or slow, spans more than one team, or when someone asks for a specific solution instead of describing what they need.
---

# Route

Problems arrive already shaped by whoever hit them. People describe a problem from where they stand, so the fix they ask for is the one that fits their part of it. Treat the description as a symptom, not a brief.

The job is to find the shortest sensible way from where things are now to what someone actually needs. Not the best way. The shortest one that works and that you can explain.

Run this before reaching for `wayfinder`, and usually instead of it. Wayfinder charts work too big for one sitting. Do this first and the work is usually no longer too big. If it still is, hand wayfinder the shape this produced.

## 1. Find the real problem

**Do not accept the frame.** "This takes too long" describes one person's view of one step. Ask what happens before it and what happens after it. Most of what makes a step hard was decided somewhere else.

**Name the person at the end.** Not the deliverable — the person. An auditor, a finance manager, a customer. Then say what they do with the output. Everything else exists in service of that. If you cannot name them, stop and find out; otherwise you are guessing at what "necessary" means.

**Follow the whole flow.** Onboarding is not an IT problem. It is recruitment, then a manager, then seniors, then finance, then IT. If each of them fixes their own step, you get five automations instead of one — and every one of them counts as a success.

Then ask: why does the work arrive in this form? Who decided that? Could it arrive differently?

## 2. Choose where to act

There are usually many routes from A to B and most of the differences do not matter. The decision that matters is **where in the flow you act.**

**As far upstream as you can reach.** Cutting the data in the source query beats filtering it after it lands, because every later step inherits the cut. The same move works on people: changing what an upstream team sends beats cleaning it up on arrival. The best step is the one you deleted.

**The smallest scope that holds the whole problem and still has someone who can say yes.** Go wider and you are right but nobody can approve it. Go narrower and you are building automation three of five.

## 3. Pick the smallest build

**The span decides the form.**

- *One owner, one user:* build it with whatever is already in your hands and expect to throw it away. A macro, a shell script, a workflow. Cheap, fast, disposable.
- *Crosses handoffs and owners:* it cannot belong to a person. Give it its own identity and access so it outlives whoever set it up. That is the actual difference between one automation and five — not a meeting, just an artefact that belongs to nobody.

**Use what is already there.** Before building a new source of truth, look for one that exists in the wrong format. An Alteryx `.yxmd` file is a complete, always-correct description of a workflow that an auditor cannot read; rendering it as a clickable node graph is a re-projection, not a build. Derived things never drift. New things always do.

**Drop anything that does not reach the output.** Trace every part back to what the person at the end does with it. If a part exists to serve another part rather than the result, it is scaffolding — cut it. Being able to build something is not a reason to build it.

## 4. Check it is real

**Every step should be observable.** You should be able to look at the state between any two steps, and when something breaks you should know which step to open. If you cannot, it is too complicated. Complicated things get rewritten; simple things let you find the one slow part and fix it. That is the point of keeping it simple — not neatness, but being able to work on it.

**Say it in plain English.** Short sentences, active voice, common words, one meaning per word. ASD-STE100 Simplified Technical English is a good discipline for this. Or tell it as a short story about the person at the end. If it cannot survive being said simply, it is not settled yet — jargon and invented words hide unfinished thinking.

## 5. Talk, then go

Talk first. One question at a time, with your recommended answer each time. The point of talking is to find the few decisions that change the shape of the thing, and to let simpler options surface. A spec written in one shot skips that and locks in the first idea anybody had.

**Stop when nothing left to discuss would change the plan.** If getting something wrong means a small fix later, do not discuss it — pick one and move on. Talking past that point is its own kind of overbuilding.

Then hand over three things and get out of the way:

1. Who the output is for, and what they do with it.
2. The shape that was agreed.
3. What was ruled out, and why — so nobody re-solves it at the wrong size.
