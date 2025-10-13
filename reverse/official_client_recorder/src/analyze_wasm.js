#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const { mkdir, readFile, writeFile, access } = require('fs/promises');
const { spawnSync } = require('child_process');
const zlib = require('zlib');
const wabtFactory = require('wabt');

function printHelp() {
  const content = `
Analyse all WebAssembly modules in a resource directory.

Usage:
  client-recorder-wasm --dir <resources_dir> [options]

Options:
  --dir <path>               Directory to scan recursively (required)
  --out <path>               Output directory (defaults to <dir>/wasm_analysis)
  --map-only                 Only list discovered modules without generating artefacts
  --keep-temp                Keep temporary extracted .wasm files (default: delete)
  --wasm-decompile <path>    Custom path to wasm-decompile binary
  --wasm-objdump <path>      Custom path to wasm-objdump binary
  -h, --help                 Show this help message
`.trim();
  console.log(content);
}

function parseArgs(argv) {
  const options = {
    keepTemp: false,
    mapOnly: false,
    wasmDecompile: null,
    wasmObjdump: null,
  };
  const args = [...argv];
  while (args.length > 0) {
    const arg = args.shift();
    switch (arg) {
      case '--dir':
        options.dir = args.shift();
        break;
      case '--out':
        options.out = args.shift();
        break;
      case '--map-only':
        options.mapOnly = true;
        break;
      case '--keep-temp':
        options.keepTemp = true;
        break;
      case '--wasm-decompile':
        options.wasmDecompile = args.shift();
        break;
      case '--wasm-objdump':
        options.wasmObjdump = args.shift();
        break;
      case '-h':
      case '--help':
        options.help = true;
        break;
      default:
        if (arg.startsWith('--dir=')) {
          const [, value] = arg.split('=');
          options.dir = value;
        } else if (arg.startsWith('--out=')) {
          const [, value] = arg.split('=');
          options.out = value;
        } else if (arg.startsWith('--wasm-decompile=')) {
          const [, value] = arg.split('=');
          options.wasmDecompile = value;
        } else if (arg.startsWith('--wasm-objdump=')) {
          const [, value] = arg.split('=');
          options.wasmObjdump = value;
        } else {
          throw new Error(`Unknown argument: ${arg}`);
        }
    }
  }
  return options;
}

async function ensureDir(targetPath) {
  await mkdir(targetPath, { recursive: true });
}

async function listFilesRecursive(root, filter) {
  const entries = await fs.promises.readdir(root, { withFileTypes: true });
  const results = [];
  for (const entry of entries) {
    const fullPath = path.join(root, entry.name);
    if (entry.isDirectory()) {
      const nested = await listFilesRecursive(fullPath, filter);
      results.push(...nested);
    } else if (filter(fullPath)) {
      results.push(fullPath);
    }
  }
  return results;
}

function bufferLooksGzip(buffer) {
  return buffer.length > 2 && buffer[0] === 0x1f && buffer[1] === 0x8b;
}

function bufferLooksWasm(buffer) {
  return (
    buffer.length > 4 &&
    buffer[0] === 0x00 &&
    buffer[1] === 0x61 &&
    buffer[2] === 0x73 &&
    buffer[3] === 0x6d
  );
}

function runTool(binary, args, options = {}) {
  const result = spawnSync(binary, args, {
    stdio: options.captureOutput ? 'pipe' : 'inherit',
    encoding: 'utf8',
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    const stderr = result.stderr || '';
    throw new Error(
      `Command "${binary} ${args.join(' ')}" failed with exit code ${result.status}${
        stderr ? `\n${stderr}` : ''
      }`,
    );
  }
  return result;
}

async function resolveExecutable(customPath, fallback) {
  if (customPath) {
    return customPath;
  }
  if (fallback) {
    try {
      await access(fallback, fs.constants.X_OK);
      return fallback;
    } catch (_) {
      // fall through
    }
  }
  return null;
}

function findOnPath(command) {
  const locator = process.platform === 'win32' ? 'where' : 'which';
  const result = spawnSync(locator, [command], { encoding: 'utf8' });
  if (result.status === 0 && result.stdout) {
    const line = result.stdout.split(/\r?\n/).find((entry) => entry && entry.trim());
    if (line) {
      return line.trim();
    }
  }
  return null;
}

async function generateWat(wabt, wasmBuffer, outputPath) {
  const module = wabt.readWasm(wasmBuffer, { readDebugNames: true });
  try {
    module.generateNames();
    module.applyNames();
    const wat = module.toText({ foldExprs: false, inlineExport: false });
    await writeFile(outputPath, wat, 'utf8');
  } finally {
    module.destroy();
  }
}

async function generateObjdump(binary, wasmPath, outputPath) {
  const result = runTool(binary, ['-x', wasmPath], { captureOutput: true });
  await writeFile(outputPath, result.stdout, 'utf8');
}

async function generateDecompile(binary, wasmPath, outputPath) {
  const result = runTool(binary, [wasmPath], { captureOutput: true });
  await writeFile(outputPath, result.stdout, 'utf8');
}

async function main(argv) {
  let options;
  try {
    options = parseArgs(argv);
  } catch (error) {
    console.error(error.message);
    printHelp();
    process.exit(1);
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

  const inputDir = path.isAbsolute(options.dir)
    ? options.dir
    : path.join(process.cwd(), options.dir);
  let outputDir = options.out
    ? path.isAbsolute(options.out)
      ? options.out
      : path.join(process.cwd(), options.out)
    : path.join(inputDir, 'wasm_analysis');

  outputDir = path.resolve(outputDir);
  await ensureDir(outputDir);

  const wasmFiles = await listFilesRecursive(inputDir, (filePath) => {
    const lower = filePath.toLowerCase();
    return lower.endsWith('.wasm') || lower.endsWith('.wasm.gz') || lower.endsWith('.wasm.br');
  });

  if (wasmFiles.length === 0) {
    console.log('[WASM] No WebAssembly modules found.');
    return;
  }

  console.log(`[WASM] Found ${wasmFiles.length} module(s). Output -> ${outputDir}`);
  if (options.mapOnly) {
    wasmFiles.forEach((file) => console.log(` - ${file}`));
    return;
  }

  const wabt = await wabtFactory();
  const tmpDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'wasm-analyze-'));
  const keepTemp = options.keepTemp;

  const wasmDecompile =
    (options.wasmDecompile && path.resolve(options.wasmDecompile)) ||
    (await resolveExecutable(process.env.WASM_DECOMPILE, null)) ||
    findOnPath('wasm-decompile') ||
    (await resolveExecutable(null, '/usr/local/bin/wasm-decompile')) ||
    (await resolveExecutable(null, '/opt/homebrew/bin/wasm-decompile')) ||
    null;

  const wasmObjdump =
    (options.wasmObjdump && path.resolve(options.wasmObjdump)) ||
    (await resolveExecutable(process.env.WASM_OBJDUMP, null)) ||
    findOnPath('wasm-objdump') ||
    (await resolveExecutable(null, '/usr/local/bin/wasm-objdump')) ||
    (await resolveExecutable(null, '/opt/homebrew/bin/wasm-objdump')) ||
    null;

  const summary = [];

  for (const file of wasmFiles) {
    const relative = path.relative(inputDir, file);
    const buffer = await readFile(file);
    let wasmBuffer = buffer;
    let compressed = null;

    if (bufferLooksGzip(buffer)) {
      wasmBuffer = zlib.gunzipSync(buffer);
      compressed = 'gzip';
    } else if (bufferLooksWasm(buffer)) {
      compressed = null;
    } else {
      // some encodings like br (brotli)
      if (file.toLowerCase().endsWith('.br')) {
        wasmBuffer = zlib.brotliDecompressSync(buffer);
        compressed = 'brotli';
      } else {
        console.warn(`[WASM] Skipping ${relative} (unknown encoding).`);
        continue;
      }
    }

    if (!bufferLooksWasm(wasmBuffer)) {
      console.warn(`[WASM] Skipping ${relative} (no wasm magic after decode).`);
      continue;
    }

    const baseName = path.basename(file).replace(/\.(wasm(\.(gz|br))?)$/i, '');
    const safeBase = baseName.replace(/[^a-zA-Z0-9._-]+/g, '_');
    const outputBaseDir = path.join(outputDir, path.dirname(relative));
    await ensureDir(outputBaseDir);

    const wasmOutPath = path.join(outputBaseDir, `${safeBase}.wasm`);
    await writeFile(wasmOutPath, wasmBuffer);

    const watOutPath = path.join(outputBaseDir, `${safeBase}.wat`);
    try {
      await generateWat(wabt, wasmBuffer, watOutPath);
    } catch (error) {
      console.warn(`[WASM] Failed to produce .wat for ${relative}: ${error.message}`);
    }

    let decompilePath = null;
    if (wasmDecompile) {
      const tmpFile = path.join(tmpDir, `${safeBase}.wasm`);
      await writeFile(tmpFile, wasmBuffer);
      const decompOut = path.join(outputBaseDir, `${safeBase}.decomp`);
      try {
        await generateDecompile(wasmDecompile, tmpFile, decompOut);
        decompilePath = decompOut;
      } catch (error) {
        console.warn(
          `[WASM] wasm-decompile failed for ${relative}: ${error.message}`,
        );
      } finally {
        if (!keepTemp) {
          await fs.promises.unlink(tmpFile).catch(() => {});
        }
      }
    }

    let objdumpPath = null;
    if (wasmObjdump) {
      const tmpFile = path.join(tmpDir, `${safeBase}-obj.wasm`);
      await writeFile(tmpFile, wasmBuffer);
      const objOut = path.join(outputBaseDir, `${safeBase}.objdump`);
      try {
        await generateObjdump(wasmObjdump, tmpFile, objOut);
        objdumpPath = objOut;
      } catch (error) {
        console.warn(
          `[WASM] wasm-objdump failed for ${relative}: ${error.message}`,
        );
      } finally {
        if (!keepTemp) {
          await fs.promises.unlink(tmpFile).catch(() => {});
        }
      }
    }

    summary.push({
      source: path.resolve(file),
      extractedWasm: wasmOutPath,
      wat: watOutPath,
      decompile: decompilePath,
      objdump: objdumpPath,
      compressed,
    });
  }

  if (!keepTemp) {
    await fs.promises.rm(tmpDir, { recursive: true, force: true }).catch(() => {});
  }

  const manifestPath = path.join(outputDir, 'manifest.json');
  const manifest = {
    generatedAt: new Date().toISOString(),
    modules: summary,
  };
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

  console.log(`[WASM] Generated artefacts for ${summary.length} module(s). Manifest -> ${manifestPath}`);
  summary.forEach((item) => {
    console.log(` - ${item.source}`);
    console.log(`   wasm: ${item.extractedWasm}`);
    console.log(`   wat:  ${item.wat}`);
    if (item.decompile) {
      console.log(`   decomp: ${item.decompile}`);
    }
    if (item.objdump) {
      console.log(`   objdump: ${item.objdump}`);
    }
  });
}

main(process.argv.slice(2)).catch((error) => {
  console.error('[WASM] Unhandled error:', error);
  process.exit(1);
});
