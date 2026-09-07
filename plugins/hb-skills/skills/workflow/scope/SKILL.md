---
name: scope
description: "Decompose work into parts before building. Surfaces gaps, assumptions, and dependencies via SIPOC review. Produces alignment artifacts: flow diagram, decisions doc, data dictionary. Sits between /grill and /go in the pipeline. Triggers: 'scope this out', 'break this down', 'map out', 'what are the moving parts', 'mermify', any multi-step process or workflow description, or 'I need to automate'. Note: this skill replaces the earlier 'mermify' skill — if someone asks for mermify, use this."
---

# Scope

Decompose an idea into its parts before building. The goal is **alignment**: everyone — including the builder agent in /go — sees the same structure, the same gaps, the same assumptions, before anyone writes a line.

Scope sits between **/grill** (sharpen the idea) and **/go** (build it). If the idea is already sharp, skip grill. If it's small enough to hold in your head, skip scope. The pipeline is: **grill → scope → call → go → handoff** — enter where the work needs you.

## Pipeline (work each stage in order)

### 1. Extract intent
Identify: goal, inputs (files/APIs/scraping/user input), outputs (Slack/email/DB/file), implied transforms between them.

### 2. Expand compressed steps
"Scrape websites" = read URL list → fetch each → parse HTML → extract structured data.
"Summarise" = collect → build prompt → LLM call → parse response.
If a step hides a sub-workflow, it becomes a `subgraph`.

### 3. Data shapes on every edge
Label every connection with its type: `List[URL]`, `{title, body, url}`, `str`, `File(json)`, `Batch[T]`. Be specific. Mark inferred shapes.

### 4. Process boundaries
Flag: config-driven values (env vars), fan-out/parallel points, LLM calls, external services, human-in-the-loop gates.

### 5. Operational behaviour
- **Delta processing**: will this run repeatedly? Default to incremental (seen-items store + change gate) unless one-shot is obvious. Surface as assumption.
- **Cost/rate**: LLM fan-outs need batching/throttling. API quotas. Scraping blocks.
- **Failure**: which steps fail transiently? Retry policy. Fan-out: halt vs continue.
- **Caching**: don't re-process unchanged items.
Add these as nodes/gates in the diagram, not footnotes.

### 6. SIPOC review (quality gate)
Check decomposition against all five before rendering:
- **S (Suppliers)**: who provides each input? Who maintains it? Can't name them = gap.
- **I (Inputs)**: hidden inputs? Credentials, domain knowledge, manual approvals, triggers.
- **P (Process)**: every step earning its place? Remove it — would customer notice?
- **O (Outputs)**: all outputs including logs, state changes, side effects, downstream feeds.
- **C (Customers)**: who receives each output? What format do they need? Customer needs shape output design.
If nothing changes after this review, you rushed it.

### 7. Render the diagram

`flowchart TD`. Node conventions:
```
id(Step)              %% default
id([Source/Sink])      %% input/output     :::io
id{Condition?}         %% decision
id[/LLM: task/]        %% AI call          :::llm
id[(Store)]            %% data store
id[[API: service]]     %% external service  :::external
```
Edge labels = data shape: `A -->|List[URL]| B`
Subgraph IDs: snake_case. Display names in brackets.
```
classDef llm fill:#a78bfa,stroke:#7c3aed,color:#fff
classDef config fill:#fbbf24,stroke:#d97706,color:#000
classDef external fill:#60a5fa,stroke:#2563eb,color:#fff
classDef io fill:#34d399,stroke:#059669,color:#fff
```

### 8. Produce artifacts

## Output: 3 artifacts + conversational intro

All docs written for a **senior stakeholder doing alignment review**, not a builder. No implementation detail, no code, no jargon. If a sentence takes longer to read than the value it delivers, cut it. Present the artifacts with a one-line summary, point the user to the decisions doc first.

### Artifact 1: `<name>.mermaid`
The flow diagram. The **main flow** (outside subgraphs) is the **spine** — the thinnest path that makes the whole thing work end to end. If this feeds into /go, the spine becomes the punch list's critical path.

### Artifact 2: `<name>_decisions.md`
The first thing a human reads. Structure:

**What this does** — 2-3 plain-English sentences.

**SIPOC summary** — one table, one row per process phase:

| Suppliers | Inputs | Process | Outputs | Customers |
|-----------|--------|---------|---------|-----------|

If the reviewer says "that's not who provides that" — fix the table before anything else.

**Assumptions I've made** — bullets, plain language, question-mark tone:
- GOOD: "Only new or changed items get processed each run — right approach?"
- BAD: "Delta processing via SHA-256 content hashing with exponential backoff"

**Open questions** — ordered by blocker impact. Short question + just enough context to answer. These feed directly into **/call** for resolution before **/go** begins.

**Dependencies** — checklist of what must exist before build:
- [ ] item

**Not included (and why)** — what the diagram doesn't cover that a real build would need.

NO implementation notes, code, or library choices in this doc.

### Artifact 3: `<name>_data.md`
Data dictionary — every shape crossing an edge in the diagram. Group in flow order. Mark `(inferred)` where assumed. One line per field.
```
## Event (after extraction)
- title: str
- date: ISO 8601 datetime
- source_url: URL
- content_hash: str
```

## Feeding into the pipeline

**Into /go**: the diagram's main flow is the **spine** — /go builds this first, then widens into subgraphs by value. Open questions and assumptions feed into /call for resolution before execution starts. The data dictionary grounds schema and interface decisions. Dependencies become the punch list's prerequisites.

**Into /to-tickets**: each subgraph or major flow segment is a natural ticket boundary. Blocking edges follow the diagram's dependency flow.

**Into /wayfinder**: if scope reveals the work is too big for one session, the diagram becomes the starting map. Subgraphs become candidate decision tickets.

## Ambiguity
Prefer over-decomposing. State assumptions explicitly. Show the detailed version, note the simpler alternative.
