# Example agent — managed-agent template

## Overview

Reference cookbook showing the dual-deployment pattern. Same source as the [`example-agent`](../../plugins/example-agent) plugin — this directory is the Managed Agent cookbook for `POST /v1/agents`.

Replace the prompt and workers with your real workflow.

## Deploy

```bash
export ANTHROPIC_API_KEY=sk-ant-...
../../scripts/deploy-managed-agent.sh example-agent
# dry-run to inspect resolved POST bodies
../../scripts/deploy-managed-agent.sh example-agent --dry-run
```

## Steering events

See [`steering-examples.json`](./steering-examples.json).

## Security & handoffs

Task-decomposition split focuses on data isolation and least-privilege. The researcher reads sources; the writer produces files but has no MCP access. Exactly one worker holds `Write`:

| Leaf | Tools | Connectors |
|---|---|---|
| `researcher` | `Read`, `Grep` | None (add MCP servers as needed) |
| **`writer`** (Write-holder) | `Read`, `Write`, `Edit` | None |

Artifacts land in `./out/research.md` and `./out/draft.md`.

**Handoff:** if the agent needs another agent's output, the orchestrator emits a `handoff_request` for the target slug; `scripts/orchestrate.py` (or your workflow engine) routes it as a new steering event. Targets must be in `ALLOWED_TARGETS` in `orchestrate.py`.
