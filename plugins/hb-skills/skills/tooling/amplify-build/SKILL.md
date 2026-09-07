# Amplify Build Skill

Scaffold, configure, and deploy an AWS Amplify Gen 2 app.

## Usage
`/amplify-build [app-name] [features: auth|data|bedrock|all]`

If args are missing, ask ONE question block (max 3 questions):
- App name + purpose
- Features: auth / data / bedrock / custom
- Deploy target: sandbox (dev) or CI/CD (prod)

---

## Phase 1 — Scaffold
Read `.amplify_build/src/scaffold.md`.
Run commands. Verify directory structure before continuing.

## Phase 2 — Backend
Load ONLY the files matching selected features:
- `auth` → `.amplify_build/src/auth.md`
- `data` or `custom schema` → `.amplify_build/src/data.md`
- `bedrock` → `.amplify_build/src/bedrock.md`

Wire everything in `amplify/backend.ts`.

## Phase 3 — Frontend
Using patterns from already-loaded feature files, wire `src/App.tsx`:
- Configure Amplify with `amplify_outputs.json`
- Generate typed client
- Build form + query call + result display

## Phase 4 — Deploy
Read `.amplify_build/src/deploy.md`. Run checklist. Deploy.

---

## Rules
- Load src/ files lazily — one phase at a time, only what's needed
- Never read all src/ files upfront
- Edit existing files; don't create extras
- `amplify_outputs.json` is auto-generated — never edit or commit it
- Confirm before `git push` or `amplify pipeline-deploy`
