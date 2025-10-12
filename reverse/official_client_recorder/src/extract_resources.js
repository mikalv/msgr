#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { mkdir, writeFile } = require('fs/promises');
const {
  decodeBodyContent,
  getHeaderValue,
  decompressBodyContent,
  persistResourceToDisk,
  maybeBeautifyResource,
  createOnceLogger,
} = require('./resource_utils');

function printHelp() {
  const content = `
Extract saved HTTP responses from a recorder capture for offline analysis.

Usage:
  client-recorder-extract --file <capture.jsonl> [options]

Options:
  --file <path>             Path to the recorder JSONL capture (required)
  --output-dir <path>       Directory to write extracted resources (default: <capture>_resources)
  --no-pretty-resources     Skip generating prettified companions (JSON/JS)
  --filter <pattern>        Only extract responses whose URL includes the pattern
  --limit <number>          Stop after extracting N matching responses
  --force                   Overwrite existing manifest/resource files
  -h, --help                Show this help message
`.trim();
  console.log(content);
}

function parseArgs(argv) {
  const options = {
    beautifyResources: true,
    force: false,
    limit: null,
    filter: null,
  };
  const args = [...argv];
  while (args.length > 0) {
    const arg = args.shift();
    switch (arg) {
      case '--file':
        options.file = args.shift();
        break;
      case '--output-dir':
        options.outputDir = args.shift();
        break;
      case '--no-pretty-resources':
        options.beautifyResources = false;
        break;
      case '--filter':
        options.filter = args.shift();
        break;
      case '--limit':
        {
          const value = args.shift();
          const parsed = Number.parseInt(value, 10);
          if (Number.isNaN(parsed) || parsed < 1) {
            throw new Error(`Invalid --limit value: ${value}`);
          }
          options.limit = parsed;
        }
        break;
      case '--force':
        options.force = true;
        break;
      case '-h':
      case '--help':
        options.help = true;
        break;
      default:
        if (arg.startsWith('--file=')) {
          const [, value] = arg.split('=');
          options.file = value;
        } else if (arg.startsWith('--output-dir=')) {
          const [, value] = arg.split('=');
          options.outputDir = value;
        } else if (arg.startsWith('--filter=')) {
          const [, value] = arg.split('=');
          options.filter = value;
        } else if (arg.startsWith('--limit=')) {
          const [, value] = arg.split('=');
          const parsed = Number.parseInt(value, 10);
          if (Number.isNaN(parsed) || parsed < 1) {
            throw new Error(`Invalid --limit value: ${value}`);
          }
          options.limit = parsed;
        } else {
          throw new Error(`Unknown argument: ${arg}`);
        }
    }
  }
  return options;
}

function deriveOutputDir(filePath, overrideDir) {
  if (overrideDir) {
    return path.isAbsolute(overrideDir)
      ? overrideDir
      : path.join(process.cwd(), overrideDir);
  }
  const absolute = path.isAbsolute(filePath) ? filePath : path.join(process.cwd(), filePath);
  const dir = path.dirname(absolute);
  const baseName = path.basename(absolute, path.extname(absolute));
  return path.join(dir, `${baseName}_resources`);
}

async function fileExists(filePath) {
  try {
    await fs.promises.access(filePath, fs.constants.F_OK);
    return true;
  } catch (_) {
    return false;
  }
}

async function loadCaptureStream(filePath) {
  const absolute = path.isAbsolute(filePath) ? filePath : path.join(process.cwd(), filePath);
  if (!(await fileExists(absolute))) {
    throw new Error(`Capture file not found: ${absolute}`);
  }
  return fs.createReadStream(absolute, { encoding: 'utf8' });
}

async function main(argv) {
  let options;
  try {
    options = parseArgs(argv);
  } catch (error) {
    console.error(error.message);
    printHelp();
    process.exit(1);
    return;
  }

  if (options.help) {
    printHelp();
    return;
  }

  if (!options.file) {
    console.error('Missing required --file argument.');
    printHelp();
    process.exit(1);
  }

  const captureStream = await loadCaptureStream(options.file);
  const outputDir = deriveOutputDir(options.file, options.outputDir);
  await mkdir(outputDir, { recursive: true });

  const manifestPath = path.join(outputDir, 'manifest.json');
  if (!options.force && (await fileExists(manifestPath))) {
    console.warn(
      `[Extract] Manifest already exists at ${manifestPath}. Pass --force to overwrite.`,
    );
  }

  const rl = readline.createInterface({
    input: captureStream,
    crlfDelay: Infinity,
  });

  const filterLower = options.filter ? options.filter.toLowerCase() : null;
  const warnDecompressionOnce = createOnceLogger('decompression-extract');
  const saved = [];
  let resourceCounter = 0;
  let processed = 0;
  let skippedNoBody = 0;
  let skippedFilter = 0;
  let skippedLimit = false;

  for await (const line of rl) {
    if (!line || !line.trim()) continue;
    let event;
    try {
      event = JSON.parse(line);
    } catch (error) {
      console.warn(`[Extract] Skipping invalid JSON line: ${error.message}`);
      continue;
    }

    if (event.type !== 'http-response') {
      continue;
    }

    if (!event.body) {
      skippedNoBody += 1;
      continue;
    }

    if (filterLower && !String(event.url || '').toLowerCase().includes(filterLower)) {
      skippedFilter += 1;
      continue;
    }

    if (options.limit && saved.length >= options.limit) {
      skippedLimit = true;
      break;
    }

    const rawBuffer = decodeBodyContent(event.body, event.base64Encoded === true);
    if (!rawBuffer || rawBuffer.length === 0) {
      skippedNoBody += 1;
      continue;
    }

    const encodingHeader = getHeaderValue(event.headers, 'content-encoding');
    const shouldAttemptDecompression =
      Boolean(encodingHeader) && event.base64Encoded === true;
    const decodedBuffer = shouldAttemptDecompression
      ? decompressBodyContent(rawBuffer, encodingHeader, warnDecompressionOnce)
      : rawBuffer;

    if (!decodedBuffer || decodedBuffer.length === 0) {
      skippedNoBody += 1;
      continue;
    }

    const currentIndex = ++resourceCounter;
    let savedPath = null;
    try {
      savedPath = await persistResourceToDisk(outputDir, event, decodedBuffer, event.requestId, currentIndex);
    } catch (error) {
      console.error(
        `[Extract] Failed to write resource for ${event.url || 'unknown URL'}: ${error.message}`,
      );
      continue;
    }

    const relPath = savedPath
      ? path.relative(outputDir, savedPath) || path.basename(savedPath)
      : null;

    let prettyRelPath = null;
    if (relPath && options.beautifyResources) {
      try {
        const pretty = await maybeBeautifyResource({
          buffer: decodedBuffer,
          response: event,
          absolutePath: savedPath,
          beautifyEnabled: options.beautifyResources,
          outputDirectory: outputDir,
        });
        if (pretty) {
          prettyRelPath = pretty;
        }
      } catch (error) {
        console.warn(`[Extract] Failed to prettify ${relPath}: ${error.message}`);
      }
    }

    processed += 1;
    saved.push({
      requestId: event.requestId,
      url: event.url,
      status: event.status,
      mimeType: event.mimeType,
      size: decodedBuffer.length,
      resourcePath: relPath,
      resourcePrettyPath: prettyRelPath,
      capturedAt: event.ts || null,
    });

    if (processed % 50 === 0) {
      console.log(`[Extract] Processed ${processed} responses...`);
    }
  }

  const summary = {
    source: path.resolve(options.file),
    totalSaved: saved.length,
    skippedNoBody,
    skippedFilter,
    reachedLimit: skippedLimit,
    outputDir: path.resolve(outputDir),
    generatedAt: new Date().toISOString(),
    responses: saved,
  };

  await writeFile(manifestPath, `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
  console.log(
    `[Extract] Wrote ${saved.length} resources to ${path.resolve(outputDir)} (manifest: ${manifestPath}).`,
  );
  if (skippedFilter > 0) {
    console.log(`[Extract] Filter skipped ${skippedFilter} responses that did not match.`);
  }
  if (skippedNoBody > 0) {
    console.log(
      `[Extract] Skipped ${skippedNoBody} responses without captured bodies. Re-run recorder with --capture-bodies to include them.`,
    );
  }
  if (skippedLimit) {
    console.log('[Extract] Extraction stopped after reaching the configured --limit.');
  }
}

main(process.argv.slice(2)).catch((error) => {
  console.error('[Extract] Unhandled error:', error);
  process.exit(1);
});
