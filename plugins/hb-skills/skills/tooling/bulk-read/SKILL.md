---
name: bulk-read
description: >
  This skill should be used when a Read tool call is blocked because the
  file exceeds the line threshold, when the user asks to "summarise a large
  file", "bulk read a file", or "get an overview of a file", or when you
  need to understand the structure of a file that is too large to read
  directly.
metadata:
  version: "0.1.0"
---

# Bulk Read

When a `Read` call is blocked by the token router hook because the file
exceeds the configured line threshold, use the `bulk_read` MCP tool to get
a structured summary from a cheap worker model.

## When to use

- A Read was blocked with a message mentioning the line threshold — call
  `bulk_read` with the file path
- You need an overview of a large file's structure before deciding which
  section to read in detail
- You want to find specific symbols, functions, or sections in a large file

## How to call it

The `bulk_read` tool takes two parameters:

- **`path`** (required): absolute file path
- **`question`** (optional): a question to focus the summary, e.g.
  "which functions handle authentication?" or "what are the exported types?"

The tool returns structured bullets. Every bullet leads with a symbol name
or line number range, giving you anchors for targeted follow-up reads.

## When NOT to use

- **File is under the threshold** — Read it normally. The hook only blocks
  files over the configured limit (default 350 lines).
- **You know which section you need** — use `Read` with `offset` and
  `limit`. Targeted reads are never blocked by the hook regardless of file
  size.
- **You need to edit the file** — worker summaries do not carry reliable
  line numbers for edits. Read the specific section with offset/limit, then
  use Edit.
- **The file is binary or an image** — the worker model is text-only.

## Typical flow

1. Attempt to Read a large file → hook blocks it
2. Call `bulk_read` with the path and an optional focusing question
3. Receive structured bullets with symbol names and line ranges
4. Use targeted `Read` (offset + limit) to fetch the exact section you need
5. Continue working with precise code rather than the full file

## Reference

See `references/bulk-reader-mode.md` for the worker model's system prompt
and output format specification.
