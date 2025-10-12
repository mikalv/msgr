const path = require('path');
const { mkdir, writeFile } = require('fs/promises');
const zlib = require('zlib');

const MAX_BEAUTIFY_BYTES = 5 * 1024 * 1024;
const JSON_MIME_TYPES = new Set([
  'application/json',
  'application/ld+json',
  'application/vnd.api+json',
  'text/json',
]);
const JS_MIME_TYPES = new Set([
  'application/javascript',
  'text/javascript',
  'application/x-javascript',
  'text/ecmascript',
  'application/ecmascript',
]);
const TEXT_MIME_PREFIXES = ['text/'];

let cachedPrettier = undefined;

function loadPrettier(logger = console) {
  if (cachedPrettier !== undefined) {
    return cachedPrettier;
  }
  try {
    // eslint-disable-next-line global-require, import/no-extraneous-dependencies
    cachedPrettier = require('prettier');
  } catch (error) {
    if (logger && typeof logger.warn === 'function') {
      logger.warn(
        '[Recorder] Optional dependency "prettier" not found. Install it to get prettified JS output.',
      );
    }
    cachedPrettier = null;
  }
  return cachedPrettier;
}

function sanitizeSegment(segment, fallback = 'part') {
  if (!segment || typeof segment !== 'string') {
    return fallback;
  }
  const cleaned = segment
    .replace(/[^a-zA-Z0-9._-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80);
  return cleaned || fallback;
}

function guessExtensionFromMime(mimeType = '') {
  if (!mimeType) return null;
  const normalized = mimeType.split(';')[0].trim().toLowerCase();
  const map = {
    'application/javascript': '.js',
    'text/javascript': '.js',
    'application/x-javascript': '.js',
    'text/html': '.html',
    'text/css': '.css',
    'application/json': '.json',
    'application/ld+json': '.json',
    'text/plain': '.txt',
    'application/x-protobuf': '.pb',
    'application/protobuf': '.pb',
    'application/vnd.google.protobuf': '.pb',
    'application/octet-stream': '.bin',
    'application/wasm': '.wasm',
  };
  return map[normalized] || null;
}

function guessCharsetFromMime(mimeType = '') {
  if (!mimeType) return null;
  const parts = mimeType.split(';').slice(1);
  for (const part of parts) {
    const trimmed = part.trim().toLowerCase();
    if (trimmed.startsWith('charset=')) {
      return trimmed.split('=')[1] || null;
    }
  }
  return null;
}

function getHeaderValue(headers, name) {
  if (!headers) return null;
  const target = name.toLowerCase();
  for (const [key, value] of Object.entries(headers)) {
    if (typeof key === 'string' && key.toLowerCase() === target) {
      if (Array.isArray(value)) {
        return value.join(', ');
      }
      return value;
    }
  }
  return null;
}

function decodeBodyContent(body, base64Encoded) {
  if (body == null) return null;
  if (base64Encoded) {
    return Buffer.from(body, 'base64');
  }
  return Buffer.from(body, 'utf8');
}

function createOnceLogger(namespace = 'recorder') {
  const seen = new Set();
  return (key, message) => {
    const compound = `${namespace}:${key}`;
    if (seen.has(compound)) return;
    seen.add(compound);
    console.warn(message);
  };
}

function decompressBodyContent(buffer, encodingHeader, warnOnce) {
  if (!buffer || buffer.length === 0 || !encodingHeader) {
    return buffer;
  }

  const encodings = String(encodingHeader)
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean);

  return encodings.reduce((acc, encoding) => {
    if (!acc || acc.length === 0) {
      return acc;
    }
    try {
      switch (encoding) {
        case 'gzip':
        case 'x-gzip':
          return zlib.gunzipSync(acc);
        case 'deflate':
          return zlib.inflateSync(acc);
        case 'br':
          if (typeof zlib.brotliDecompressSync === 'function') {
            return zlib.brotliDecompressSync(acc);
          }
          return acc;
        default:
          return acc;
      }
    } catch (error) {
      if (typeof warnOnce === 'function') {
        warnOnce(
          encoding,
          `[Recorder] Failed to decompress response body (${encoding}): ${error.message}`,
        );
      }
      return acc;
    }
  }, buffer);
}

function looksLikeJsonString(content) {
  if (typeof content !== 'string') return false;
  const trimmed = content.trim();
  if (!trimmed) return false;
  return (
    trimmed.startsWith('{') ||
    trimmed.startsWith('[') ||
    trimmed.startsWith('"') ||
    trimmed.startsWith('true') ||
    trimmed.startsWith('false') ||
    trimmed.startsWith('null') ||
    trimmed.startsWith('-') ||
    /^-?\d/.test(trimmed)
  );
}

function safeJsonFormat(input) {
  try {
    const parsed = JSON.parse(input);
    return `${JSON.stringify(parsed, null, 2)}\n`;
  } catch (_) {
    return null;
  }
}

function isLikelyJson(mimeType, filePath, content) {
  if (mimeType) {
    const normalized = mimeType.split(';')[0].trim().toLowerCase();
    if (JSON_MIME_TYPES.has(normalized)) {
      return true;
    }
  }
  const ext = path.extname(filePath || '').toLowerCase();
  if (ext === '.json') return true;
  return looksLikeJsonString(content);
}

function isLikelyJavaScript(mimeType, filePath) {
  if (mimeType) {
    const normalized = mimeType.split(';')[0].trim().toLowerCase();
    if (JS_MIME_TYPES.has(normalized)) {
      return true;
    }
  }
  const ext = path.extname(filePath || '').toLowerCase();
  return ext === '.js' || ext === '.mjs' || ext === '.cjs';
}

function isLikelyTextual(mimeType) {
  if (!mimeType) return false;
  const normalized = mimeType.split(';')[0].trim().toLowerCase();
  if (TEXT_MIME_PREFIXES.some((prefix) => normalized.startsWith(prefix))) {
    return true;
  }
  return (
    JSON_MIME_TYPES.has(normalized) ||
    JS_MIME_TYPES.has(normalized) ||
    normalized.endsWith('+json')
  );
}

async function maybeBeautifyResource({
  buffer,
  response,
  absolutePath,
  beautifyEnabled,
  outputDirectory,
}) {
  if (
    !beautifyEnabled ||
    !buffer ||
    buffer.length === 0 ||
    !absolutePath ||
    buffer.length > MAX_BEAUTIFY_BYTES
  ) {
    return null;
  }

  const mimeType = response?.mimeType || getHeaderValue(response?.headers, 'content-type');
  if (!isLikelyTextual(mimeType) && !isLikelyJson(null, absolutePath)) {
    return null;
  }

  const charset = guessCharsetFromMime(mimeType) || 'utf8';
  let textContent;
  try {
    textContent = buffer.toString(charset);
  } catch (_) {
    textContent = buffer.toString('utf8');
  }

  const normalizedMime = mimeType ? mimeType.split(';')[0].trim().toLowerCase() : null;
  let formatted = null;
  let extension = '';

  if (isLikelyJson(normalizedMime, absolutePath, textContent)) {
    const prettier = loadPrettier();
    if (prettier) {
      try {
        formatted = prettier.format(textContent, { parser: 'json', tabWidth: 2 }) + '\n';
        extension = '.pretty.json';
      } catch (_) {
        formatted = safeJsonFormat(textContent);
        extension = '.pretty.json';
      }
    } else {
      formatted = safeJsonFormat(textContent);
      extension = '.pretty.json';
    }
  } else if (isLikelyJavaScript(normalizedMime, absolutePath)) {
    const prettier = loadPrettier();
    if (prettier) {
      try {
        formatted = prettier.format(textContent, {
          parser: 'babel',
          tabWidth: 2,
          semi: true,
        });
        extension = '.pretty.js';
      } catch (error) {
        console.warn(
          `[Recorder] Failed to prettify JavaScript resource (${path.basename(
            absolutePath,
          )}): ${error.message}`,
        );
        formatted = null;
      }
    }
  }

  if (!formatted) {
    return null;
  }

  const { dir, name } = path.parse(absolutePath);
  const prettyPath = path.join(dir, `${name}${extension}`);
  await writeFile(prettyPath, formatted, 'utf8');
  const prettyRelative = path.relative(outputDirectory, prettyPath);
  return prettyRelative && prettyRelative !== '' ? prettyRelative : path.basename(prettyPath);
}

function buildResourcePath(baseDir, responseUrl, mimeType, requestId, index) {
  const paddedIndex = String(index).padStart(5, '0');
  let hostSegment = 'unknown-host';
  let directorySegments = [];
  let baseName = 'resource';
  let extension = '';

  try {
    const url = new URL(responseUrl);
    hostSegment = sanitizeSegment(url.host, 'unknown-host');
    const pathParts = url.pathname.split('/').filter(Boolean);
    const sanitizedParts = pathParts.map((part) => sanitizeSegment(part)).filter(Boolean);
    if (sanitizedParts.length > 0) {
      directorySegments = sanitizedParts.slice(0, -1);
      baseName = sanitizedParts[sanitizedParts.length - 1];
    } else {
      baseName = 'index';
    }

    const lastPart = pathParts.length > 0 ? pathParts[pathParts.length - 1] : '';
    const extFromPath = lastPart ? path.extname(lastPart) : '';
    if (extFromPath) {
      extension = extFromPath.slice(0, 16);
      const stem = lastPart.slice(0, Math.max(1, lastPart.length - extFromPath.length));
      baseName = sanitizeSegment(stem, baseName);
    }
  } catch (_) {
    // Keep defaults when URL parsing fails (data: URIs, etc.)
  }

  if (!extension) {
    extension = guessExtensionFromMime(mimeType) || '.bin';
  }

  const uniqueSuffix = sanitizeSegment(requestId || `req${index}`, `req${index}`);
  const limitedDirs = [hostSegment, ...directorySegments].slice(0, 6);
  const fileName = `${paddedIndex}-${baseName}-${uniqueSuffix}${extension}`;
  const directoryPath = path.join(baseDir, ...limitedDirs);
  return path.join(directoryPath, fileName);
}

async function persistResourceToDisk(baseDir, response, bodyBuffer, requestId, index) {
  if (!baseDir || !bodyBuffer || bodyBuffer.length === 0 || !response?.url) {
    return null;
  }
  const fullPath = buildResourcePath(baseDir, response.url, response.mimeType, requestId, index);
  await mkdir(path.dirname(fullPath), { recursive: true });
  await writeFile(fullPath, bodyBuffer);
  return fullPath;
}

module.exports = {
  MAX_BEAUTIFY_BYTES,
  sanitizeSegment,
  guessExtensionFromMime,
  guessCharsetFromMime,
  getHeaderValue,
  decodeBodyContent,
  createOnceLogger,
  decompressBodyContent,
  looksLikeJsonString,
  safeJsonFormat,
  isLikelyJson,
  isLikelyJavaScript,
  isLikelyTextual,
  maybeBeautifyResource,
  buildResourcePath,
  persistResourceToDisk,
};
