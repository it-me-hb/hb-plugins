#!/usr/bin/env node

/**
 * Token Router MCP Server
 *
 * Exposes the bulk_read tool — reads a large file, sends it to a cheap
 * worker model via Bedrock, and returns structured bullets. The expensive
 * model never sees the raw file content.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { readFileSync } from 'fs';
import { resolve, dirname, basename, extname } from 'path';
import { fileURLToPath } from 'url';
import { invokeWorker } from './worker.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------------------
// Config & mode prompt
// ---------------------------------------------------------------------------

const configPath = resolve(__dirname, '../config.json');
let config = {};
try {
  config = JSON.parse(readFileSync(configPath, 'utf-8'));
} catch {
  process.stderr.write('token-router: could not load config.json, using defaults\n');
}

const modePath = resolve(__dirname, '../skills/bulk-read/references/bulk-reader-mode.md');
let modePrompt = '';
try {
  modePrompt = readFileSync(modePath, 'utf-8');
} catch {
  // Inline fallback if file is missing
  modePrompt = [
    'You are a file summarisation worker.',
    'Return ONLY structured bullets. Every bullet leads with a symbol name or line number range.',
    'No prose, no preamble, no markdown fences.',
  ].join(' ');
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

const server = new Server(
  { name: 'token-router', version: '0.1.0' },
  { capabilities: { tools: {} } }
);

// -- List tools -------------------------------------------------------------

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'bulk_read',
      description: [
        'Read a large file through a cheap worker model that returns structured bullets.',
        'Use this when a direct Read is blocked because the file exceeds the line threshold.',
        'Each bullet leads with a symbol name or line number so you can target follow-up reads.',
      ].join(' '),
      inputSchema: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: 'Absolute path to the file to summarise.',
          },
          question: {
            type: 'string',
            description:
              'Optional question to focus the summary (e.g. "which functions handle auth?").',
          },
        },
        required: ['path'],
      },
    },
  ],
}));

// -- Call tool ---------------------------------------------------------------

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name !== 'bulk_read') {
    return {
      content: [{ type: 'text', text: `Unknown tool: ${name}` }],
      isError: true,
    };
  }

  const filePath = args.path;
  const question = args.question || null;

  // Read the file
  let content;
  try {
    content = readFileSync(filePath, 'utf-8');
  } catch (err) {
    return {
      content: [{ type: 'text', text: `Cannot read file: ${err.message}` }],
      isError: true,
    };
  }

  const lineCount = content.split('\n').length;
  const ext = extname(filePath).slice(1) || 'txt';
  const name_ = basename(filePath);

  // Build user message
  const fileParts = [
    `<file path="${filePath}" name="${name_}" ext="${ext}" lines="${lineCount}">`,
    content,
    '</file>',
  ];

  if (question) {
    fileParts.push('', `Focus on: ${question}`);
  }

  const userMessage = fileParts.join('\n');

  // Invoke worker
  let result;
  try {
    result = await invokeWorker(config, modePrompt, userMessage);
  } catch (err) {
    return {
      content: [
        {
          type: 'text',
          text: `Worker invocation failed: ${err.message}\n\nFallback: use Read with offset and limit to read specific sections of the file.`,
        },
      ],
      isError: true,
    };
  }

  const header = `## ${name_} — ${lineCount.toLocaleString()} lines\n\n`;

  return {
    content: [{ type: 'text', text: header + result.text }],
  };
});

// -- Start -------------------------------------------------------------------

const transport = new StdioServerTransport();
await server.connect(transport);
