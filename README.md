# Claude Marketplace Template

A starter Claude Code marketplace, modelled on [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) with the dual-deployment ([Cowork plugin](https://claude.com/product/cowork) + [Managed Agent](https://docs.claude.com/en/api/managed-agents)) machinery from [`anthropics/claude-for-financial-services`](https://github.com/anthropics/claude-for-financial-services). Fork it to bootstrap your own team or organisation marketplace.

## Two ways from one source

Every agent in this template ships **two ways from one source**: install it as a Claude Code or Cowork plugin, or deploy it through `POST /v1/agents` behind your own workflow engine. Same system prompt, same skills — you choose where it runs.

```
plugins/<slug>/agents/<slug>.md       ← single source of truth (system prompt)
plugins/<slug>/skills/                ← single source of truth (skills)
        │
        ├── installed via marketplace.json  →  Claude Code / Cowork (interactive)
        └── referenced by cookbook agent.yaml →  Managed Agents API (headless)
```

## Structure

```
.
├── .claude-plugin/marketplace.json   # registers every plugin
├── plugins/                          # interactive plugins
│   └── <slug>/
│       ├── .claude-plugin/plugin.json
│       ├── agents/<slug>.md          # system prompt (referenced by cookbook)
│       ├── skills/                   # skills the agent uses
│       ├── commands/                 # slash commands (optional)
│       ├── hooks/                    # event hooks (optional)
│       └── .mcp.json                 # MCP servers (optional)
├── managed-agent-cookbooks/          # headless deployment manifests
│   └── <slug>/
│       ├── agent.yaml                # orchestrator → POST /v1/agents
│       ├── subagents/*.yaml          # depth-1 leaf workers
│       ├── steering-examples.json
│       └── README.md
└── scripts/
    ├── deploy-managed-agent.sh       # resolve manifest → POST /v1/agents
    ├── check.py                      # lint manifests + verify references
    ├── validate.py                   # JSON-schema gate for worker output
    ├── orchestrate.py                # reference cross-agent handoff loop
    └── test-cookbooks.sh             # dry-run every cookbook
```

## Install (interactive)

Add the marketplace, then install a plugin:

```
/plugin marketplace add https://github.com/HBarnes_quantium/claude-marketplace-template
/plugin install my-first-plugin@claude-marketplace-template
```

Update later with:

```
/plugin marketplace update claude-marketplace-template
/plugin update my-first-plugin@claude-marketplace-template
```

Or browse interactively with `/plugin > Discover`.

## Deploy (headless)

```bash
export ANTHROPIC_API_KEY=sk-ant-...
scripts/deploy-managed-agent.sh example-agent
# dry-run first to inspect the resolved POST bodies without hitting the API
scripts/deploy-managed-agent.sh example-agent --dry-run
```

The deploy script resolves manifest conveniences (`system: {file: ...}`, `skills: [{from_plugin: ...}]`, `callable_agents: [{manifest: ...}]`) into real `POST /v1/agents` payloads, uploads skills via `/v1/skills`, and creates leaf workers before the orchestrator. See [`managed-agent-cookbooks/README.md`](./managed-agent-cookbooks/README.md) for the manifest contract.

## Development

```bash
# Lint manifests and verify cross-references
python3 scripts/check.py

# Dry-run every cookbook
bash scripts/test-cookbooks.sh
```

## Plugin structure

Each plugin follows the standard layout:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json      # plugin metadata (required)
├── .mcp.json            # MCP server config (optional)
├── commands/            # slash commands (optional)
├── agents/              # agent definitions (optional)
├── skills/              # skill definitions (optional)
├── hooks/               # event hooks (optional)
└── README.md            # documentation
```

## Contributing

Add a new directory under `/plugins`, then register it in `.claude-plugin/marketplace.json`. If you want it deployable as a managed agent too, add a matching `managed-agent-cookbooks/<slug>/` referencing the same `agents/<slug>.md`. See [`plugins/example-agent`](./plugins/example-agent) and [`managed-agent-cookbooks/example-agent`](./managed-agent-cookbooks/example-agent) for a worked reference.

## Documentation

- [Claude Code plugins](https://code.claude.com/docs/en/plugins)
- [Managed Agents API](https://docs.claude.com/en/api/managed-agents)
