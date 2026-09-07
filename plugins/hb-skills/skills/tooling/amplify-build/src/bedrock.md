# Bedrock Integration

## amplify/backend.ts
```ts
import { defineBackend } from "@aws-amplify/backend";
import { data } from "./data/resource";
import { auth } from "./auth/resource";
import { PolicyStatement } from "aws-cdk-lib/aws-iam";

const backend = defineBackend({ auth, data });

const bedrockDS = backend.data.resources.graphqlApi.addHttpDataSource(
  "bedrockDS",
  "https://bedrock-runtime.[REGION].amazonaws.com",
  {
    authorizationConfig: {
      signingRegion: "[REGION]",
      signingServiceName: "bedrock",
    },
  }
);

bedrockDS.grantPrincipal.addToPrincipalPolicy(
  new PolicyStatement({
    resources: ["arn:aws:bedrock:*::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"],
    actions: ["bedrock:InvokeModel"],
  })
);
```
Replace `[REGION]` — AU cross-region profile: `ap-southeast-2`, model path: `au.anthropic.claude-sonnet-4-5-20250929-v1:0`

## amplify/data/resource.ts — wire the data source
```ts
.handler(a.handler.custom({ entry: "./bedrock.js", dataSource: "bedrockDS" }))
```

## amplify/data/bedrock.js — AppSync JS resolver
```js
export function request(ctx) {
  const prompt = `Your prompt here: ${ctx.args.input}`;
  return {
    resourcePath: "/model/[MODEL_PATH]/invoke",
    method: "POST",
    params: {
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: 1000,
        messages: [{ role: "user", content: [{ type: "text", text: prompt }] }],
      }),
    },
  };
}

export function response(ctx) {
  if (ctx.result.statusCode !== 200)
    return { error: `HTTP ${ctx.result.statusCode}: ${ctx.result.body}` };
  const parsed = JSON.parse(ctx.result.body);
  return { body: parsed.content?.[0]?.text ?? null };
}
```

## Model IDs (Bedrock)
| Model | ID |
|---|---|
| Claude Sonnet 4.5 | `anthropic.claude-sonnet-4-5-20250929-v1:0` |
| Claude Haiku 4.5 | `anthropic.claude-haiku-4-5-20251001` |
| Claude Sonnet 4.6 | `anthropic.claude-sonnet-4-6` |

AU cross-region prefix: `au.` + model ID → use as `resourcePath` model segment.
