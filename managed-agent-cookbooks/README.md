# Managed-agent cookbooks

Each directory here is a deploy manifest for the [Claude Managed Agents API](https://docs.claude.com/en/api/managed-agents) (`POST /v1/agents`). The cookbook references the **same system prompt and skills** as the corresponding plugin under `../plugins/<slug>/`, so there's one source of truth and two surfaces:

- Plugin under `/plugins/<slug>/` — installed in Claude Code or Cowork, runs interactively.
- Cookbook here — deployed via `scripts/deploy-managed-agent.sh <slug>`, runs headlessly behind your own workflow engine.

## Anatomy of a cookbook

```
managed-agent-cookbooks/<slug>/
├── agent.yaml               # orchestrator (POST /v1/agents)
├── subagents/*.yaml         # depth-1 leaf workers
├── steering-examples.json   # example natural-language events that drive the agent
└── README.md                # security tier + handoff notes
```

## Manifest conveniences

`agent.yaml` uses the real `POST /v1/agents` field names plus a few resolver shortcuts that `scripts/deploy-managed-agent.sh` expands before posting:

| Manifest convention | Resolves to |
|---|---|
| `system: {file: ../../plugins/<slug>/agents/<slug>.md, append: "..."}` | `system: "<inlined contents + append>"` |
| `system: {text: "..."}` | `system: "<text>"` |
| `skills: [{from_plugin: ../../plugins/<slug>}]` | uploads every `skills/*` under that dir → `[{type: custom, skill_id: ...}, ...]` |
| `skills: [{path: ../../plugins/<slug>/skills/<name>}]` | uploaded individually, referenced by `skill_id` |
| `callable_agents: [{manifest: ./subagents/<name>.yaml}]` | created first, referenced by agent id |

## Conventions

- **Depth 1 only.** An orchestrator can call leaf workers; workers can't call further subagents (research-preview limit).
- **Exactly one leaf has `Write`.** Reader workers are read-only with relevant MCP servers; the writer worker is the only one that produces files. Mark it with **bold** in your README's leaf table.
- **Reader workers SHOULD have `output_schema`.** It's stripped before POST but used by `scripts/validate.py` to gate the JSON before the orchestrator consumes it.
- **Cross-agent handoffs are allowlisted.** Agents emit `handoff_request` in their output; `scripts/orchestrate.py` (or your control plane) routes them as new steering events to allowlisted targets.

## Deploy

```bash
export ANTHROPIC_API_KEY=sk-ant-...
scripts/deploy-managed-agent.sh <slug>
# or dry-run to inspect resolved POST bodies without hitting the API
scripts/deploy-managed-agent.sh <slug> --dry-run
```

See [`example-agent/`](./example-agent) for a worked reference.
