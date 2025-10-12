#!/usr/bin/env node

const path = require('path');
const fs = require('fs');
const { stat, readdir, readFile } = require('fs/promises');
const { maybeBeautifyResource } = require('./resource_utils');

function printHelp() {
  const content = `
Generate prettified companions (JSON/JS) for resources captured by the recorder.

Usage:
  client-recorder-pretty --dir <resources_dir>
  client-recorder-pretty --file <resource_path>

Options:
  --dir <path>       Process every resource under the directory recursively
  --file <path>      Prettify a single resource file
  --include-pretty   Also reprocess existing *.pretty.{json,js} files
  --max-bytes <num>  Skip files larger than this many bytes (default: 5242880)
  -h, --help         Show this help message
`.trim();
  console.log(content);
}

function parseArgs(argv) {
  const options = {
    includePretty: false,
    maxBytes: 5 * 1024 * 1024,
  };
  const args = [...argv];
  while (args.length > 0) {
    const arg = args.shift();
    switch (arg) {
      case '--dir':
        options.dir = args.shift();
        break;
      case '--file':
        options.file = args.shift();
        break;
      case '--include-pretty':
        options.includePretty = true;
        break;
      case '--max-bytes':
        {
          const value = args.shift();
          const parsed = Number.parseInt(value, 10);
          if (Number.isNaN(parsed) || parsed < 1) {
            throw new Error(`Invalid --max-bytes value: ${value}`);
          }
          options.maxBytes = parsed;
        }
        break;
      case '-h':
      case '--help':
        options.help = true;
        break;
      default:
        if (arg.startsWith('--dir=')) {
          const [, value] = arg.split('=');
          options.dir = value;
        } else if (arg.startsWith('--file=')) {
          const [, value] = arg.split('=');
          options.file = value;
        } else if (arg.startsWith('--max-bytes=')) {
          const [, value] = arg.split('=');
          const parsed = Number.parseInt(value, 10);
          if (Number.isNaN(parsed) || parsed < 1) {
            throw new Error(`Invalid --max-bytes value: ${value}`);
          }
          options.maxBytes = parsed;
        } else {
          throw new Error(`Unknown argument: ${arg}`);
        }
    }
  }
  return options;
}

async function pathExists(targetPath) {
  try {
    await stat(targetPath);
    return true;
  } catch (_) {
    return false;
  }
}

async function collectFiles(root, includePretty) {
  const results = [];
  const queue = [root];
  while (queue.length > 0) {
    const current = queue.pop();
    const entries = await readdir(current, { withFileTypes: true });
    for (const entry of entries) {
      const entryPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        queue.push(entryPath);
        continue;
      }
      if (!includePretty && /\.pretty\.(json|js)$/i.test(entry.name)) {
        continue;
      }
      if (entry.name === 'manifest.json') {
        continue;
      }
      const fileStat = await stat(entryPath);
      if (!fileStat.isFile()) continue;
      results.push({ path: entryPath, size: fileStat.size });
    }
  }
  return results;
}

async function processFile(filePath, options) {
  const absolutePath = path.resolve(filePath);
  const rootDir = options.rootDir || path.dirname(absolutePath);
  const fileStat = await stat(absolutePath);
  if (!fileStat.isFile()) {
    return { path: absolutePath, skipped: true, reason: 'not-a-file' };
  }

  if (!options.includePretty && /\.pretty\.(json|js)$/i.test(absolutePath)) {
    return { path: absolutePath, skipped: true, reason: 'already-pretty' };
  }

  if (fileStat.size > options.maxBytes) {
    return { path: absolutePath, skipped: true, reason: 'too-large', size: fileStat.size };
  }

  const buffer = await readFile(absolutePath);
  if (!buffer || buffer.length === 0) {
    return { path: absolutePath, skipped: true, reason: 'empty' };
  }

  const prettyPath = await maybeBeautifyResource({
    buffer,
    response: {},
    absolutePath,
    beautifyEnabled: true,
    outputDirectory: rootDir,
  });

  if (!prettyPath) {
    return { path: absolutePath, skipped: true, reason: 'not-textual' };
  }

  return {
    path: absolutePath,
    prettyPath: path.isAbsolute(prettyPath) ? prettyPath : path.join(rootDir, prettyPath),
    skipped: false,
  };
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

  if (!options.dir && !options.file) {
    console.error('Specify either --dir or --file.');
    printHelp();
    process.exit(1);
  }

  if (options.dir && options.file) {
    console.error('Choose only one of --dir or --file.');
    process.exit(1);
  }

  const summary = {
    processed: 0,
    prettified: 0,
    skipped: 0,
    skippedReasons: {},
    outputs: [],
  };

  if (options.dir) {
    const absoluteDir = path.isAbsolute(options.dir)
      ? options.dir
      : path.join(process.cwd(), options.dir);

    if (!(await pathExists(absoluteDir))) {
      console.error(`Directory not found: ${absoluteDir}`);
      process.exit(1);
    }

    const files = await collectFiles(absoluteDir, options.includePretty);
    summary.totalCandidates = files.length;
    for (const file of files) {
      const result = await processFile(file.path, {
        includePretty: options.includePretty,
        maxBytes: options.maxBytes,
        rootDir: absoluteDir,
      });
      summary.processed += 1;
      if (result.skipped) {
        summary.skipped += 1;
        summary.skippedReasons[result.reason] =
          (summary.skippedReasons[result.reason] || 0) + 1;
        continue;
      }
      summary.prettified += 1;
      summary.outputs.push({
        source: path.relative(absoluteDir, result.path),
        pretty: path.relative(absoluteDir, result.prettyPath),
      });
      if (summary.prettified % 25 === 0) {
        console.log(`[Pretty] Generated ${summary.prettified} prettified files so far...`);
      }
    }
  } else if (options.file) {
    const absoluteFile = path.isAbsolute(options.file)
      ? options.file
      : path.join(process.cwd(), options.file);

    if (!(await pathExists(absoluteFile))) {
      console.error(`File not found: ${absoluteFile}`);
      process.exit(1);
    }

    const result = await processFile(absoluteFile, {
      includePretty: options.includePretty,
      maxBytes: options.maxBytes,
      rootDir: path.dirname(absoluteFile),
    });
    summary.processed = 1;
    if (result.skipped) {
      summary.skipped = 1;
      summary.skippedReasons[result.reason] = 1;
    } else {
      summary.prettified = 1;
      summary.outputs.push({
        source: path.basename(result.path),
        pretty: path.basename(result.prettyPath),
      });
    }
  }

  console.log(
    `[Pretty] Processed ${summary.processed} file(s); generated ${summary.prettified} prettified companions.`,
  );
  if (summary.skipped > 0) {
    console.log('[Pretty] Skipped files by reason:', summary.skippedReasons);
  }
  if (summary.outputs.length > 0) {
    console.log('[Pretty] Outputs:');
    for (const entry of summary.outputs) {
      console.log(`  - ${entry.source} -> ${entry.pretty}`);
    }
  }
}

main(process.argv.slice(2)).catch((error) => {
  console.error('[Pretty] Unhandled error:', error);
  process.exit(1);
});
