# Scaffold

## Commands
```bash
npm create vite@latest [app-name] -- --template react-ts -y
cd [app-name]
npm install
npm create amplify@latest -y
npm install aws-amplify @aws-amplify/ui-react
```

## Expected structure
```
[app-name]/
  amplify/
    auth/resource.ts
    data/resource.ts
    backend.ts
    package.json
    tsconfig.json
  src/
    App.tsx
    main.tsx
  index.html
  package.json
  vite.config.ts
```
`amplify_outputs.json` appears after first sandbox run — do not create manually.

## main.tsx boilerplate
```tsx
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.tsx";
import "@aws-amplify/ui-react/styles.css";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

## tsconfig.app.json — add if missing
```json
{ "compilerOptions": { "verbatimModuleSyntax": true } }
```
Use `import type` for type-only imports when `verbatimModuleSyntax` is on.
