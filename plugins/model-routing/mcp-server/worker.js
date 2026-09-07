/**
 * Worker model invocation via AWS Bedrock.
 *
 * Sends a file to a cheap model with a structured-summary prompt and
 * returns the text response. Uses the standard AWS credential chain.
 */

import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from '@aws-sdk/client-bedrock-runtime';

/**
 * Invoke the worker model on Bedrock.
 *
 * @param {object}  config       - Plugin config (workerModel, region, temperature, maxTokens)
 * @param {string}  systemPrompt - The bulk-reader mode prompt
 * @param {string}  userMessage  - File content wrapped in tags, plus optional question
 * @returns {Promise<{text: string, usage: {input: number, output: number}}>}
 */
export async function invokeWorker(config, systemPrompt, userMessage) {
  const client = new BedrockRuntimeClient({
    region: config.region || 'ap-southeast-2',
  });

  const body = JSON.stringify({
    anthropic_version: 'bedrock-2023-05-31',
    max_tokens: config.maxTokens || 4096,
    temperature: config.temperature ?? 0.2,
    system: systemPrompt,
    messages: [{ role: 'user', content: userMessage }],
  });

  const command = new InvokeModelCommand({
    modelId: config.workerModel || 'anthropic.claude-haiku-4-5-20251001-v1:0',
    body,
    contentType: 'application/json',
    accept: 'application/json',
  });

  const startMs = Date.now();

  let response;
  try {
    response = await client.send(command);
  } catch (err) {
    const code = err.name || err.constructor?.name || 'UnknownError';
    throw new Error(
      `Bedrock invocation failed (${code}): ${err.message}`
    );
  }

  const elapsedMs = Date.now() - startMs;
  const parsed = JSON.parse(new TextDecoder().decode(response.body));

  // Log metrics to stderr (stdout is reserved for MCP protocol)
  const usage = parsed.usage || {};
  process.stderr.write(
    JSON.stringify({
      event: 'worker_invocation',
      model: config.workerModel,
      region: config.region,
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens,
      latency_ms: elapsedMs,
    }) + '\n'
  );

  const text = (parsed.content || [])
    .filter((c) => c.type === 'text')
    .map((c) => c.text)
    .join('\n');

  return {
    text,
    usage: {
      input: usage.input_tokens || 0,
      output: usage.output_tokens || 0,
    },
  };
}
