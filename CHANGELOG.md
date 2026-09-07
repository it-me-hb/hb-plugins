# Changelog

## 1.1.0 — 2026-09-07

### Bugs fixed
- Removed stale `skills:` block from `example-agent/agent.yaml` that referenced a non-existent `skills/` directory (`check.py` now exits 0)
- Updated worker model ID from Haiku 3.5 to Haiku 4.5 (`anthropic.claude-haiku-4-5-20251001-v1:0`) in `config.json` and `worker.js`
- Removed `head`/`tail` from the `check-file-size` hook's block list — they are inherently bounded reads
- Added YAML frontmatter to `amplify-build` SKILL.md and fixed internal `.amplify_build/src/` path references to `src/`
- Fixed repo identity: renamed from `claude-marketplace-template` / `hb-plugin-marketplace` to `hb-plugins` throughout README and `marketplace.json`

### Moved
- `bulk-read` skill moved from `hb-skills/skills/tooling/` to `model-routing/skills/` — it is coupled to the `check-file-size` hook and `bulk_read` MCP tool
- `server.js` now resolves `bulk-reader-mode.md` from `CLAUDE_PLUGIN_ROOT` when available, with stderr warning on fallback

### Added
- `/handoff` skill: packages work-in-progress (state, decision ledger, next steps, assumptions to verify) for a later session or agent
- Decision ledger format in `/call` with `Assumes`, `Depends on`, and `Rev?` columns, persisted to `.scratch/decisions.md`
- Assumption rechecking at `/go` checkpoints and `/brb` work stage changes
- `Assumes` column in `/grill` summary table, with instruction to seed `.scratch/decisions.md`
- Scope assumptions flow into ledger rows when entering `/go`

### Removed
- Dangling skill references: `/prototype`, `/research`, `/to-tickets`, `/wayfinder` cleared from all skill files

### Changed
- `model-routing` plugin description updated to explain what it actually does
- `route` §5 consolidated to two lines pointing to `/grill`
- `hb-skills` version → 1.1.0, `model-routing` version → 1.1.0
