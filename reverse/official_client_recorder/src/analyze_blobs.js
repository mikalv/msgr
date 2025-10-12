#!/usr/bin/env node

const path = require('path');
const fs = require('fs');
const { stat, readdir, readFile, writeFile } = require('fs/promises');
const {
  isLikelyJson,
  isLikelyJavaScript,
  looksLikeJsonString,
} = require('./resource_utils');

function printHelp() {
  const content = `
Inspect an extracted resource directory and surface interesting blobs.

Usage:
  client-recorder-blobs --dir <resources_dir> [options]

Options:
  --dir <path>       Resource directory produced by the recorder or extractor (required)
  --top <number>     Number of largest files to list (default: 15)
  --json <path>      Write the full analysis report to this JSON file
  --include-pretty   Include *.pretty.{json,js} files in the analysis (default skips them)
  -h, --help         Show this help message
`.trim();
  console.log(content);
}

function parseArgs(argv) {
  const options = {
    top: 15,
    includePretty: false,
  };
  const args = [...argv];
  while (args.length > 0) {
    const arg = args.shift();
    switch (arg) {
      case '--dir':
        options.dir = args.shift();
        break;
      case '--top':
        {
          const value = args.shift();
          const parsed = Number.parseInt(value, 10);
          if (Number.isNaN(parsed) || parsed < 1) {
            throw new Error(`Invalid --top value: ${value}`);
          }
          options.top = parsed;
        }
        break;
      case '--json':
        options.json = args.shift();
        break;
      case '--include-pretty':
        options.includePretty = true;
        break;
      case '-h':
      case '--help':
        options.help = true;
        break;
      default:
        if (arg.startsWith('--dir=')) {
          const [, value] = arg.split('=');
          options.dir = value;
        } else if (arg.startsWith('--top=')) {
          const [, value] = arg.split('=');
          const parsed = Number.parseInt(value, 10);
          if (Number.isNaN(parsed) || parsed < 1) {
            throw new Error(`Invalid --top value: ${value}`);
          }
          options.top = parsed;
        } else if (arg.startsWith('--json=')) {
          const [, value] = arg.split('=');
          options.json = value;
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
      if (entry.name === 'manifest.json') continue;

      const fileStat = await stat(entryPath);
      if (!fileStat.isFile()) continue;
      results.push({ path: entryPath, size: fileStat.size, mtime: fileStat.mtime });
    }
  }

  return results;
}

function detectProtobuf(buffer, filePath) {
  const lowerPath = filePath.toLowerCase();
  if (lowerPath.endsWith('.pb') || lowerPath.endsWith('.proto')) {
    return true;
  }
  const needles = ['proto', 'protobuf', 'PbField', 'jspb', 'message'];
  return needles.some((needle) => buffer.includes(Buffer.from(needle)));
}

function classifyFile(buffer, filePath) {
  const tags = new Set();
  let snippet = null;
  let textual = false;

  const MAX_SAMPLE = Math.min(buffer.length, 128 * 1024);
  const sample = buffer.slice(0, MAX_SAMPLE);
  const utfSample = sample.toString('utf8');

  if (looksLikeJsonString(utfSample)) {
    tags.add('json');
    textual = true;
  } else if (isLikelyJavaScript(null, filePath)) {
    tags.add('javascript');
    textual = true;
  } else if (/\.wasm$/i.test(filePath)) {
    tags.add('wasm');
  } else if (/\.svg$/i.test(filePath)) {
    tags.add('svg');
    textual = true;
  } else if (/\.css$/i.test(filePath)) {
    tags.add('css');
    textual = true;
  } else if (/\.html?$/i.test(filePath)) {
    tags.add('html');
    textual = true;
  } else if (/\.ts$/i.test(filePath)) {
    tags.add('typescript');
    textual = true;
  } else if (/\.map$/i.test(filePath)) {
    tags.add('sourcemap');
    textual = true;
  }

  if (detectProtobuf(buffer, filePath)) {
    tags.add('protobuf');
  }

  if (tags.size === 0 && textual) {
    tags.add('text');
  } else if (tags.size === 0) {
    tags.add('binary');
  }

  if (textual) {
    const lines = utfSample.split(/\r?\n/).slice(0, 5);
    snippet = lines.join('\n');
  }

  return { tags: Array.from(tags), snippet };
}

async function analyzeDirectory(rootDir, includePretty) {
  const files = await collectFiles(rootDir, includePretty);
  const summaries = [];
  let totalSize = 0;

  for (const file of files) {
    const buffer = await readFile(file.path);
    totalSize += buffer.length;
    const classification = classifyFile(buffer, file.path);
    const record = {
      path: path.relative(rootDir, file.path),
      size: buffer.length,
      modifiedAt: file.mtime.toISOString(),
      tags: classification.tags,
      snippet: classification.snippet,
    };
    summaries.push(record);
  }

  summaries.sort((a, b) => b.size - a.size);

  const protobufCandidates = summaries.filter((item) => item.tags.includes('protobuf'));
  const jsonFiles = summaries.filter((item) => item.tags.includes('json'));
  const javascriptBundles = summaries.filter((item) => item.tags.includes('javascript'));

  return {
    directory: path.resolve(rootDir),
    totalFiles: summaries.length,
    totalSize,
    topFiles: summaries.slice(0, 50),
    protobufCandidates,
    jsonFiles,
    javascriptBundles,
  };
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

function printSummary(report, topCount) {
  console.log(`Resource directory: ${report.directory}`);
  console.log(`Total files: ${report.totalFiles}`);
  console.log(`Total size: ${formatBytes(report.totalSize)}`);
  console.log('');
  console.log(`Top ${Math.min(topCount, report.topFiles.length)} largest files:`);

  for (const item of report.topFiles.slice(0, topCount)) {
    console.log(
      `  - ${item.path} (${formatBytes(item.size)}) [${item.tags.join(', ')}]`,
    );
  }

  if (report.protobufCandidates.length > 0) {
    console.log('');
    console.log('Likely protobuf bundles:');
    for (const item of report.protobufCandidates.slice(0, topCount)) {
      console.log(
        `  - ${item.path} (${formatBytes(item.size)}) [${item.tags.join(', ')}]`,
      );
    }
  }
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

  if (!options.dir) {
    console.error('Missing required --dir argument.');
    printHelp();
    process.exit(1);
  }

  const absoluteDir = path.isAbsolute(options.dir)
    ? options.dir
    : path.join(process.cwd(), options.dir);

  if (!(await pathExists(absoluteDir))) {
    console.error(`Directory not found: ${absoluteDir}`);
    process.exit(1);
  }

  const report = await analyzeDirectory(absoluteDir, options.includePretty);
  printSummary(report, options.top);

  if (options.json) {
    const outputPath = path.isAbsolute(options.json)
      ? options.json
      : path.join(process.cwd(), options.json);
    const payload = {
      generatedAt: new Date().toISOString(),
      ...report,
    };
    await writeFile(outputPath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
    console.log(`\nWrote analysis report to ${outputPath}`);
  }
}

main(process.argv.slice(2)).catch((error) => {
  console.error('[Blob Analyzer] Unhandled error:', error);
  process.exit(1);
});
