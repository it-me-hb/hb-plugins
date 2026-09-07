# Auth

## amplify/auth/resource.ts
```ts
import { defineAuth } from "@aws-amplify/backend";

export const auth = defineAuth({
  loginWith: { email: true },
});
```

## Common options
```ts
// Add MFA
loginWith: { email: true },
multifactor: { mode: "OPTIONAL", totp: true }

// Add OAuth / social
loginWith: {
  email: true,
  externalProviders: {
    google: { clientId: secret("GOOGLE_CLIENT_ID"), clientSecret: secret("GOOGLE_CLIENT_SECRET") },
    callbackUrls: ["http://localhost:5173/"],
    logoutUrls: ["http://localhost:5173/"],
  }
}
```

## Frontend — wrap app with Authenticator
```tsx
import { Authenticator } from "@aws-amplify/ui-react";

function App() {
  return (
    <Authenticator>
      {({ signOut, user }) => (
        <main>
          <p>Hello {user?.username}</p>
          <button onClick={signOut}>Sign out</button>
          {/* app content */}
        </main>
      )}
    </Authenticator>
  );
}
```

## Auth modes for data
- `apiKey` — unauthenticated access, expires in N days
- `userPool` — Cognito authenticated users
- `iam` — IAM role (server-to-server)
Set `authMode` on `generateClient<Schema>({ authMode: "userPool" })`.
