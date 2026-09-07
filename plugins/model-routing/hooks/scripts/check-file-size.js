#!/usr/bin/env node

/**
 * PreToolUse hook: check-file-size
 *
 * Fires on Read and Bash tool calls. Blocks reads of files over the
 * configured line threshold and directs the model to use bulk_read instead.
 *
 * Targeted reads (offset or limit set) pass through unconditionally —
 * the model already knows which section it needs.
 */

const fs = require('fs');
const path = require('path');

// Load config from plugin root
const configPath = path.resolve(__dirname, '../../config.json');
let config = { threshold: 350 };
try {
  config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
} catch {
  // Fall back to default threshold
}

const THRESHOLD = config.threshold || 350;

/**
 * Count lines in a file without reading it all into a single string.
 * Falls back to full-read for non-regular files.
 */
function countLines(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  let count = 1;
  for (let i = 0; i < content.length; i++) {
    if (content[i] === '\n') count++;
  }
  return count;
}

/**
 * Check whether a file path points to a readable regular file.
 */
function isReadableFile(filePath) {
  try {
    const stat = fs.statSync(filePath);
    return stat.isFile();
  } catch {
    return false;
  }
}

/**
 * Extract a file path from a bash command that starts with a read utility.
 * Handles simple quoting but not all edge cases.
 */
function extractBashReadTarget(command) {
  const pattern = /\b(cat|head|tail|less|more)\s+(?:(?:-\S+)\s+)*["']?([^\s"'|;>&$]+)/;
  const match = command.match(pattern);
  return match ? match[2] : null;
}

async function main() {
  let raw = '';
  process.stdin.setEncoding('utf-8');
  for await (const chunk of process.stdin) {
    raw += chunk;
  }

  const data = JSON.parse(raw);
  const toolName = data.tool_name;
  const toolInput = data.tool_input || {};

  // --- Read tool ---
  if (toolName === 'Read') {
    // Targeted reads always pass through
    if (toolInput.offset != null || toolInput.limit != null) {
      process.stdout.write(JSON.stringify({ decision: 'approve' }));
      return;
    }

    const filePath = toolInput.file_path;
    if (!filePath || !isReadableFile(filePath)) {
      process.stdout.write(JSON.stringify({ decision: 'approve' }));
      return;
    }

    try {
      const lineCount = countLines(filePath);
      if (lineCount >= THRESHOLD) {
        process.stdout.write(JSON.stringify({
          decision: 'block',
          reason: [
            `This file is ${lineCount.toLocaleString()} lines (threshold: ${THRESHOLD}).`,
            'Use the bulk_read tool to get a structured summary instead.',
            'If you need a specific section, use Read with offset and limit — targeted reads are never blocked.'
          ].join(' ')
        }));
        return;
      }
    } catch {
      // Can't count lines — let the read through
    }

    process.stdout.write(JSON.stringify({ decision: 'approve' }));
    return;
  }

  // --- Bash tool: detect cat/head/tail/less/more ---
  if (toolName === 'Bash') {
    const command = toolInput.command || '';
    const targetPath = extractBashReadTarget(command);

    if (targetPath && isReadableFile(targetPath)) {
      try {
        const lineCount = countLines(targetPath);
        if (lineCount >= THRESHOLD) {
          process.stdout.write(JSON.stringify({
            decision: 'block',
            reason: [
              `The target file ${path.basename(targetPath)} is ${lineCount.toLocaleString()} lines (threshold: ${THRESHOLD}).`,
              'Use the bulk_read tool to get a structured summary instead.',
              'If you need a specific section, use Read with offset and limit — targeted reads are never blocked.'
            ].join(' ')
          }));
          return;
        }
      } catch {
        // Can't count lines — let it through
      }
    }

    process.stdout.write(JSON.stringify({ decision: 'approve' }));
    return;
  }

  // Everything else passes through
  process.stdout.write(JSON.stringify({ decision: 'approve' }));
}

main().catch(() => {
  // On any unexpected error, approve — never break the session
  process.stdout.write(JSON.stringify({ decision: 'approve' }));
});
