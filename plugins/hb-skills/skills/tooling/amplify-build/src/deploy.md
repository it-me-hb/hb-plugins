# Deploy

## Pre-deploy checklist
- [ ] `amplify_outputs.json` exists (run sandbox once if not)
- [ ] No hardcoded secrets in source files
- [ ] `amplify_outputs.json` in `.gitignore`
- [ ] TypeScript compiles: `npx tsc --noEmit`
- [ ] App builds: `npm run build`
- [ ] Auth mode matches frontend client config
- [ ] Lock file survives a clean install: `rm -rf node_modules && npm ci`
      (this is the first command the Amplify pipeline runs — `npm run build` alone won't catch a broken lock)

## Sandbox (dev / local)
```bash
npx ampx sandbox          # deploys backend, watches for changes
# In separate terminal:
npm run dev               # starts Vite frontend
```
Sandbox auto-generates `amplify_outputs.json`. Teardown: `npx ampx sandbox delete`.

## CI/CD via Amplify Hosting (prod)
1. Push repo to GitHub
2. AWS Console → Amplify → Create new app → connect GitHub repo → main branch
3. Amplify auto-detects Gen 2, sets build command (`npm run build`), output dir (`dist`)
4. Every push to `main` triggers rebuild + redeploy

## Manual pipeline deploy
```bash
npx ampx pipeline-deploy --branch main --app-id [AMPLIFY_APP_ID]
```

## Common errors
| Error | Fix |
|---|---|
| `amplify_outputs.json not found` | Run `npx ampx sandbox` first |
| `UnauthorizedException` on query | Check `authMode` matches schema auth rules |
| `HTTP 403` from Bedrock | IAM policy missing or wrong model ARN |
| `verbatimModuleSyntax` error | Use `import type` for type-only imports |
| `npm ci` fails: `Missing: @opentelemetry/core@2.0.0 / uuid@9.0.1 from lock file` | Known npm bug with bundledDependencies in `@aws-amplify/data-construct` — regenerating the lock will NOT fix it (npm install, deleting the lock, and npm 10 all reproduce the same broken lock). Add to package.json: `"overrides": { "@opentelemetry/core": "^2.8.0", "uuid": "^11.1.1" }`, then `rm -rf node_modules package-lock.json && npm install` and verify with `npm ci` |
| Bedrock `ResourceNotFoundException` | Model not enabled in Bedrock console for that region |
