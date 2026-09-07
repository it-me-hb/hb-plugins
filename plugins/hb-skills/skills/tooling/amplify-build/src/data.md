# Data (AppSync / DynamoDB)

## amplify/data/resource.ts — CRUD model
```ts
import { type ClientSchema, a, defineData } from "@aws-amplify/backend";

const schema = a.schema({
  Todo: a
    .model({ content: a.string() })
    .authorization((allow) => [allow.owner()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: "userPool",
  },
});
```

## Custom query + custom type
```ts
const schema = a.schema({
  MyResponse: a.customType({
    body: a.string(),
    error: a.string(),
  }),
  myQuery: a
    .query()
    .arguments({ input: a.string() })
    .returns(a.ref("MyResponse"))
    .authorization((allow) => [allow.authenticated()])
    .handler(
      a.handler.custom({ entry: "./resolver.js", dataSource: "myDS" })
    ),
});
```

## Frontend client
```tsx
import { generateClient } from "aws-amplify/data";
import type { Schema } from "../amplify/data/resource";

const client = generateClient<Schema>({ authMode: "userPool" });

// CRUD
const { data } = await client.models.Todo.list();
await client.models.Todo.create({ content: "Buy milk" });

// Custom query
const { data, errors } = await client.queries.myQuery({ input: "hello" });
```

## Auth options per model
```ts
.authorization((allow) => [
  allow.owner(),           // only creator can read/write
  allow.authenticated(),   // any logged-in user
  allow.publicApiKey(),    // anyone with API key
  allow.guest(),           // unauthenticated
])
```
