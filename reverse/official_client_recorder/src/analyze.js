#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const DEFAULT_RULES_PATH = path.join(__dirname, '..', 'config', 'rules.json');

function printHelp() {
  const text = `
Traffic capture analyzer.

Usage:
  npm run analyze -- --file <captures/session.jsonl> [options]
  node src/analyze.js --file <captures/session.jsonl> [options]

Options:
  --file <path>        JSONL capture to inspect (required)
  --type <value>       Only include events of this type (repeatable)
  --request-id <id>    Filter by requestId / WebSocket id
  --search <string>    Case-insensitive substring search across key fields
  --regex <pattern>    JavaScript regular expression applied to JSON lines
  --limit <number>     Max number of matching events to print (default 20)
  --top <number>       Number of top endpoints to show in summary (default 10)
  --rules <path>       Path to analyzer rules JSON (default config/rules.json)
  --include-assets     Do not filter out images/CSS/fonts and other noise
  --highlight-threshold <num>  Minimum score for auto-highlights (default 5)
  --no-summary         Skip aggregated overview output
  --show-bodies        Print body/payload fields for matching events
  --help               Show this message
`.trim();
  console.log(text);
}

function parseArgs(argv) {
  const opts = {
    types: new Set(),
    limit: 20,
    top: 10,
    summary: true,
    showBodies: false,
    rulesPath: DEFAULT_RULES_PATH,
    includeAssets: false,
    highlightThreshold: 5,
  };

  const args = [...argv];
  while (args.length) {
    const arg = args.shift();
    switch (arg) {
      case '--help':
      case '-h':
        opts.help = true;
        break;
      case '--file':
        opts.file = args.shift();
        break;
      case '--type':
        opts.types.add(args.shift());
        break;
      case '--request-id':
        opts.requestId = args.shift();
        break;
      case '--search':
        opts.search = args.shift();
        break;
      case '--regex':
        opts.regex = args.shift();
        break;
      case '--limit':
        {
          const value = Number.parseInt(args.shift(), 10);
          if (Number.isNaN(value) || value <= 0) {
            throw new Error('Invalid --limit value');
          }
          opts.limit = value;
        }
        break;
      case '--top':
        {
          const value = Number.parseInt(args.shift(), 10);
          if (Number.isNaN(value) || value <= 0) {
            throw new Error('Invalid --top value');
          }
          opts.top = value;
        }
        break;
      case '--rules':
        opts.rulesPath = args.shift();
        break;
      case '--include-assets':
        opts.includeAssets = true;
        break;
      case '--highlight-threshold':
        {
          const value = Number.parseInt(args.shift(), 10);
          if (Number.isNaN(value) || value < 0) {
            throw new Error('Invalid --highlight-threshold value');
          }
          opts.highlightThreshold = value;
        }
        break;
      case '--no-summary':
        opts.summary = false;
        break;
      case '--show-bodies':
        opts.showBodies = true;
        break;
      default:
        if (arg.startsWith('--file=')) {
          opts.file = arg.split('=')[1];
        } else if (arg.startsWith('--type=')) {
          opts.types.add(arg.split('=')[1]);
        } else if (arg.startsWith('--request-id=')) {
          opts.requestId = arg.split('=')[1];
        } else if (arg.startsWith('--search=')) {
          opts.search = arg.split('=')[1];
        } else if (arg.startsWith('--regex=')) {
          opts.regex = arg.split('=')[1];
        } else if (arg.startsWith('--limit=')) {
          const value = Number.parseInt(arg.split('=')[1], 10);
          if (Number.isNaN(value) || value <= 0) {
            throw new Error('Invalid --limit value');
          }
          opts.limit = value;
        } else if (arg.startsWith('--top=')) {
          const value = Number.parseInt(arg.split('=')[1], 10);
          if (Number.isNaN(value) || value <= 0) {
            throw new Error('Invalid --top value');
          }
          opts.top = value;
        } else if (arg.startsWith('--rules=')) {
          opts.rulesPath = arg.split('=')[1];
        } else if (arg === '--exclude-assets') {
          opts.includeAssets = false;
        } else if (arg.startsWith('--highlight-threshold=')) {
          const value = Number.parseInt(arg.split('=')[1], 10);
          if (Number.isNaN(value) || value < 0) {
            throw new Error('Invalid --highlight-threshold value');
          }
          opts.highlightThreshold = value;
        } else if (arg === '--summary') {
          opts.summary = true;
        } else {
          throw new Error(`Unknown option: ${arg}`);
        }
    }
  }

  if (opts.regex) {
    try {
      opts.regexInstance = new RegExp(opts.regex, 'i');
    } catch (error) {
      throw new Error(`Invalid regex pattern: ${error.message}`);
    }
  }

  if (opts.search) {
    opts.searchLower = opts.search.toLowerCase();
  }

  return opts;
}

function normaliseEndpoint(urlString, method = '') {
  if (!urlString) return method ? `${method} <unknown>` : '<unknown>';
  try {
    const parsed = new URL(urlString);
    const base = `${parsed.origin}${parsed.pathname}`;
    return method ? `${method} ${base}` : base;
  } catch (_) {
    return method ? `${method} ${urlString}` : urlString;
  }
}

function ensureFilePath(baseDir, filePath) {
  if (!filePath) return null;
  return path.isAbsolute(filePath) ? filePath : path.join(baseDir, filePath);
}

function ensureArray(value) {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

function loadRules(cwd, rulesPath) {
  const resolved = ensureFilePath(cwd, rulesPath || DEFAULT_RULES_PATH);
  if (!resolved || !fs.existsSync(resolved)) {
    if (rulesPath && resolved !== DEFAULT_RULES_PATH) {
      console.warn(`[warn] Rules file not found at ${resolved}, falling back to defaults.`);
    }
    return compileRules({});
  }
  try {
    const raw = fs.readFileSync(resolved, 'utf8');
    const parsed = JSON.parse(raw);
    return compileRules(parsed);
  } catch (error) {
    console.error(`[warn] Failed to load rules from ${resolved}: ${error.message}`);
    return compileRules({});
  }
}

function compileRules(rules) {
  const noise = rules.noise || {};
  const categories = ensureArray(rules.categories).map((category) => {
    const match = category.match || {};
    return {
      name: category.name || 'uncategorised',
      score: category.score || 0,
      noise: Boolean(category.noise),
      match: {
        types: ensureArray(match.types),
        methods: ensureArray(match.methods).map((method) => method.toUpperCase()),
        resourceTypes: ensureArray(match.resourceTypes),
        urlContains: ensureArray(match.urlContains).map((value) => value.toLowerCase()),
        urlRegexes: ensureArray(match.urlPatterns).map((pattern) => new RegExp(pattern, 'i')),
        mimePrefixes: ensureArray(match.mimePrefixes),
        headers: ensureArray(match.headers).map((header) => header.toLowerCase()),
        wsDirections: ensureArray(match.wsDirections),
        metadataEvents: ensureArray(match.metadataEvents),
      },
    };
  });

  return {
    noise: {
      resourceTypes: new Set(ensureArray(noise.resourceTypes)),
      mimePrefixes: ensureArray(noise.mimePrefixes),
      urlRegexes: ensureArray(noise.urlPatterns).map((pattern) => new RegExp(pattern, 'i')),
    },
    categories,
    boosts: {
      methods: rules.boosts?.methods || {},
      statusBuckets: rules.boosts?.statusBuckets || {},
      wsDirections: rules.boosts?.wsDirections || {},
    },
  };
}

function normaliseHeaders(headers) {
  if (!headers) return {};
  return Object.entries(headers).reduce((acc, [key, value]) => {
    acc[key.toLowerCase()] = value;
    return acc;
  }, {});
}

function parseUrlDetails(rawUrl) {
  if (!rawUrl) return null;
  try {
    const parsed = new URL(rawUrl);
    const segments = parsed.pathname.split('/').filter(Boolean);
    return {
      parsed,
      hasQuery: Boolean(parsed.search && parsed.search.length > 1),
      pathSegments: segments,
    };
  } catch (_) {
    return null;
  }
}

function matchesCategory(event, category, headersLower) {
  const { match } = category;
  if (!match) return false;
  if (match.types.length > 0 && !match.types.includes(event.type)) {
    return false;
  }
  if (match.methods.length > 0) {
    const method = (event.method || '').toUpperCase();
    if (!method || !match.methods.includes(method)) {
      return false;
    }
  }
  if (match.resourceTypes.length > 0) {
    const resourceType = event.resourceType || '';
    if (!resourceType || !match.resourceTypes.includes(resourceType)) {
      return false;
    }
  }
  if (match.urlContains.length > 0) {
    const url = (event.url || '').toLowerCase();
    if (!url || !match.urlContains.some((needle) => url.includes(needle))) {
      return false;
    }
  }
  if (match.urlRegexes.length > 0) {
    const url = event.url || '';
    if (!url || !match.urlRegexes.some((regex) => regex.test(url))) {
      return false;
    }
  }
  if (match.mimePrefixes.length > 0) {
    const mime = event.mimeType || '';
    if (!mime || !match.mimePrefixes.some((prefix) => mime.startsWith(prefix))) {
      return false;
    }
  }
  if (match.headers.length > 0) {
    if (!headersLower) return false;
    const headerNames = Object.keys(headersLower);
    if (!match.headers.some((expected) => headerNames.includes(expected))) {
      return false;
    }
  }
  if (match.wsDirections.length > 0) {
    if (event.type !== 'ws-frame') return false;
    if (!match.wsDirections.includes(event.direction)) {
      return false;
    }
  }
  if (match.metadataEvents.length > 0) {
    if (event.type !== 'metadata') return false;
    if (!match.metadataEvents.includes(event.event)) {
      return false;
    }
  }
  return true;
}

function classifyEvent(event, rules) {
  const headersLower = normaliseHeaders(event.headers);
  const url = event.url || '';
  const resourceType = event.resourceType || '';
  const mimeType = event.mimeType || '';
  const urlInfo = parseUrlDetails(url);

  const baseNoise =
    (resourceType && rules.noise.resourceTypes.has(resourceType)) ||
    (mimeType && rules.noise.mimePrefixes.some((prefix) => mimeType.startsWith(prefix))) ||
    (url && rules.noise.urlRegexes.some((regex) => regex.test(url)));

  const categories = [];
  let score = 0;
  let noiseThroughCategory = false;

  rules.categories.forEach((category) => {
    if (matchesCategory(event, category, headersLower)) {
      categories.push(category.name);
      score += category.score || 0;
      if (category.noise) {
        noiseThroughCategory = true;
      }
    }
  });

  if (event.type === 'http-request' || event.type === 'http-response') {
    score += 1;
  }
  if (event.type === 'ws-frame') {
    score += 1;
  }

  if (event.method) {
    const method = event.method.toUpperCase();
    if (method === 'GET' && urlInfo && !urlInfo.hasQuery) {
      score -= 1;
    }
    if (rules.boosts.methods[method]) {
      score += rules.boosts.methods[method];
    }
  }

  if (typeof event.status === 'number') {
    const bucket = `${Math.floor(event.status / 100)}xx`;
    if (rules.boosts.statusBuckets[bucket]) {
      score += rules.boosts.statusBuckets[bucket];
    }
  }

  if (event.type === 'ws-frame' && event.direction) {
    const boost = rules.boosts.wsDirections?.[event.direction];
    if (boost) {
      score += boost;
    }
  }

  if (event.postData || event.body || event.payload) {
    score += 1;
  }

  const method = event.method ? event.method.toUpperCase() : null;
  const isPlainDocumentGet =
    method === 'GET' &&
    urlInfo &&
    !urlInfo.hasQuery &&
    (!resourceType || resourceType === 'Document') &&
    urlInfo.pathSegments.length <= 1;

  const computedNoise = Boolean(baseNoise || noiseThroughCategory || (isPlainDocumentGet && categories.length === 0));

  return {
    categories,
    score,
    headersLower,
    isNoise: computedNoise,
  };
}

function matchesFilters(event, opts, rawLine, classification) {
  if (!opts.includeAssets && classification?.isNoise) {
    return false;
  }
  if (opts.types.size > 0 && !opts.types.has(event.type)) {
    return false;
  }
  if (opts.requestId && event.requestId !== opts.requestId) {
    return false;
  }
  if (opts.searchLower) {
    const haystacks = [
      event.url,
      event.message,
      event.payload,
      event.body,
      JSON.stringify(event.headers || {}),
      rawLine,
    ].filter(Boolean);
    const matched = haystacks.some((item) =>
      item.toString().toLowerCase().includes(opts.searchLower),
    );
    if (!matched) return false;
  }
  if (opts.regexInstance && !opts.regexInstance.test(rawLine)) {
    return false;
  }
  return true;
}

const INTERESTING_HEADER_PATTERNS = [
  /authorization/i,
  /cookie/i,
  /token/i,
  /x-.*auth/i,
  /x-.*token/i,
  /^x-fb-/i,
  /^x-msgr/i,
  /csrf/i,
];

const RESERVED_METADATA_EVENTS = new Set(['session-start', 'session-end']);

function looksInterestingHeader(name) {
  return INTERESTING_HEADER_PATTERNS.some((pattern) => pattern.test(name));
}

function truncateValue(value, max = 160) {
  if (!value) return value;
  const stringified = Array.isArray(value) ? value.join('; ') : String(value);
  return stringified.length > max
    ? `${stringified.slice(0, max)}…`
    : stringified;
}

function buildSummary(options) {
  return {
    total: 0,
    noiseCount: 0,
    highlightThreshold: options.highlightThreshold ?? 5,
    types: new Map(),
    categories: new Map(),
    httpRequests: new Map(),
    httpMethods: new Map(),
    postPutEndpoints: new Map(),
    httpResponses: {
      byStatus: new Map(),
      failures: [],
      setCookies: [],
    },
    wsFrames: {
      total: 0,
      incoming: 0,
      outgoing: 0,
      byOpcode: new Map(),
    },
    automationErrors: 0,
    consoleErrors: [],
    pageErrors: [],
    interestingHeaders: [],
    metadataEvents: [],
    topEvents: [],
  };
}

function recordHighlight(summary, event, classification) {
  if (!classification) return;
  if (classification.isNoise) return;
  if (classification.score < summary.highlightThreshold) return;
  const entry = {
    score: classification.score,
    type: event.type,
    ts: event.ts || null,
    url: event.url || null,
    method: event.method || null,
    status: event.status !== undefined ? event.status : null,
    requestId: event.requestId || null,
    direction: event.direction || null,
    categories: classification.categories,
  };
  summary.topEvents.push(entry);
  summary.topEvents.sort((a, b) => b.score - a.score);
  if (summary.topEvents.length > 15) {
    summary.topEvents.length = 15;
  }
}

function summariseEvent(event, summary, classification) {
  summary.total += 1;
  const current = summary.types.get(event.type) || 0;
  summary.types.set(event.type, current + 1);

  if (classification?.isNoise) {
    summary.noiseCount += 1;
  }

  classification?.categories.forEach((category) => {
    const existing = summary.categories.get(category) || 0;
    summary.categories.set(category, existing + 1);
  });

  const includeInAggregates = !classification?.isNoise;

  if (event.type === 'http-request' && includeInAggregates) {
    const key = normaliseEndpoint(event.url, event.method);
    const existingCount = summary.httpRequests.get(key) || 0;
    summary.httpRequests.set(key, existingCount + 1);
    const method = (event.method || 'GET').toUpperCase();
    const methodCount = summary.httpMethods.get(method) || 0;
    summary.httpMethods.set(method, methodCount + 1);
    if (method === 'POST' || method === 'PUT') {
      const postCount = summary.postPutEndpoints.get(key) || 0;
      summary.postPutEndpoints.set(key, postCount + 1);
    }
    if (event.headers) {
      Object.entries(event.headers).forEach(([headerName, headerValue]) => {
        if (looksInterestingHeader(headerName)) {
          if (summary.interestingHeaders.length < 50) {
            summary.interestingHeaders.push({
              direction: 'request',
              name: headerName,
              value: truncateValue(headerValue),
              url: event.url,
              ts: event.ts,
            });
          }
        }
      });
    }
  }

  if (event.type === 'http-response' && includeInAggregates) {
    const statusKey = `${event.status}`;
    const existing = summary.httpResponses.byStatus.get(statusKey) || 0;
    summary.httpResponses.byStatus.set(statusKey, existing + 1);
    if (event.failureReason) {
      summary.httpResponses.failures.push({
        url: event.url,
        reason: event.failureReason,
        status: event.status,
        ts: event.ts,
      });
    }
    if (event.headers) {
      const headers = event.headers;
      Object.entries(headers).forEach(([headerName, headerValue]) => {
        if (looksInterestingHeader(headerName)) {
          if (summary.interestingHeaders.length < 50) {
            summary.interestingHeaders.push({
              direction: 'response',
              name: headerName,
              value: truncateValue(headerValue),
              url: event.url,
              ts: event.ts,
            });
          }
        }
      });
      const setCookie = headers['set-cookie'] || headers['Set-Cookie'];
      if (setCookie) {
        const items = Array.isArray(setCookie) ? setCookie : [setCookie];
        items.forEach((cookie) => {
          if (summary.httpResponses.setCookies.length < 50) {
            summary.httpResponses.setCookies.push({
              ts: event.ts,
              url: event.url,
              value: truncateValue(cookie),
            });
          }
        });
      }
    }
  }

  if (event.type === 'http-failure') {
    summary.httpResponses.failures.push({
      url: event.url,
      reason: event.reason,
      status: null,
      ts: event.ts,
    });
  }

  if (event.type === 'ws-frame') {
    summary.wsFrames.total += 1;
    if (includeInAggregates) {
      const opcodeKey = `${event.opcode}`;
      const opcodeCount = summary.wsFrames.byOpcode.get(opcodeKey) || 0;
      summary.wsFrames.byOpcode.set(opcodeKey, opcodeCount + 1);
      if (event.direction === 'incoming') {
        summary.wsFrames.incoming += 1;
      } else if (event.direction === 'outgoing') {
        summary.wsFrames.outgoing += 1;
      }
    }
  }

  if (event.type === 'automation-error') {
    summary.automationErrors += 1;
  }

  if (event.type === 'console') {
    summary.consoleErrors.push({
      text: event.text,
      ts: event.ts,
      location: event.location,
    });
  }

  if (event.type === 'page-error') {
    summary.pageErrors.push({
      message: event.message,
      stack: event.stack,
      ts: event.ts,
    });
  }

  if (event.type === 'metadata') {
    if (!RESERVED_METADATA_EVENTS.has(event.event)) {
      summary.metadataEvents.push({
        ts: event.ts || null,
        event: event.event || null,
        note: event.note || null,
      });
    }
  }

  recordHighlight(summary, event, classification);
}

function formatCountMap(map, topN) {
  return Array.from(map.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, topN)
    .map(([label, count]) => `  ${count.toString().padStart(6)}  ${label}`)
    .join('\n');
}

function printSummary(summary, opts) {
  console.log('=== Summary ===');
  console.log(`Events: ${summary.total}`);
  if (summary.noiseCount > 0) {
    console.log(`Noise filtered: ${summary.noiseCount} (use --include-assets to view)`);
  }
  if (summary.types.size > 0) {
    console.log('\nPer type:');
    console.log(formatCountMap(summary.types, summary.types.size));
  }
  if (summary.categories.size > 0) {
    console.log('\nCategories:');
    console.log(formatCountMap(summary.categories, summary.categories.size));
  }
  if (summary.httpMethods.size > 0) {
    console.log('\nHTTP methods:');
    console.log(formatCountMap(summary.httpMethods, summary.httpMethods.size));
  }
  if (summary.httpRequests.size > 0) {
    console.log('\nTop HTTP requests:');
    console.log(formatCountMap(summary.httpRequests, opts.top));
  }
  if (summary.postPutEndpoints.size > 0) {
    console.log('\nPOST/PUT endpoints:');
    console.log(formatCountMap(summary.postPutEndpoints, opts.top));
  }
  if (summary.httpResponses.byStatus.size > 0) {
    console.log('\nHTTP status distribution:');
    console.log(formatCountMap(summary.httpResponses.byStatus, summary.httpResponses.byStatus.size));
  }
  if (summary.httpResponses.failures.length > 0) {
    console.log('\nHTTP failures:');
    summary.httpResponses.failures.forEach((failure) => {
      const status = failure.status ? `status=${failure.status} ` : '';
      console.log(`  [${failure.ts}] ${status}${failure.reason} => ${failure.url}`);
    });
  }
  if (summary.httpResponses.setCookies.length > 0) {
    console.log('\nSet-Cookie headers:');
    summary.httpResponses.setCookies.forEach((entry) => {
      console.log(`  [${entry.ts}] ${entry.url}`);
      console.log(`    ${entry.value}`);
    });
  } else {
    console.log('\nSet-Cookie headers: none observed.');
  }
  if (summary.wsFrames.total > 0) {
    console.log('\nWebSocket frames:');
    console.log(`  total=${summary.wsFrames.total} incoming=${summary.wsFrames.incoming} outgoing=${summary.wsFrames.outgoing}`);
    if (summary.wsFrames.byOpcode.size > 0) {
      console.log(formatCountMap(summary.wsFrames.byOpcode, summary.wsFrames.byOpcode.size));
    }
  }
  if (summary.topEvents.length > 0) {
    console.log('\nHigh-value events:');
    summary.topEvents.forEach((entry) => {
      const parts = [`score=${entry.score}`, entry.type];
      if (entry.method) parts.push(`method=${entry.method}`);
      if (entry.status !== null) parts.push(`status=${entry.status}`);
      if (entry.direction) parts.push(`direction=${entry.direction}`);
      if (entry.categories.length > 0) parts.push(`cat=${entry.categories.join(',')}`);
      console.log(`  [${entry.ts || 'no-ts'}] ${parts.join(' ')}`);
      if (entry.url) {
        console.log(`    ${entry.url}`);
      }
    });
  }
  if (summary.automationErrors > 0) {
    console.log(`\nAutomation errors: ${summary.automationErrors}`);
  }
  if (summary.consoleErrors.length > 0) {
    console.log('\nConsole output:');
    summary.consoleErrors.forEach((entry) => {
      console.log(`  [${entry.ts}] ${entry.text}`);
    });
  }
  if (summary.pageErrors.length > 0) {
    console.log('\nPage errors:');
    summary.pageErrors.forEach((entry) => {
      console.log(`  [${entry.ts}] ${entry.message}`);
    });
  }
  if (summary.metadataEvents.length > 0) {
    console.log('\nMetadata events:');
    summary.metadataEvents.forEach((entry) => {
      console.log(`  [${entry.ts}] ${entry.event || 'event'} ${entry.note || ''}`.trim());
    });
  }
  if (summary.interestingHeaders.length > 0) {
    console.log('\nInteresting headers:');
    summary.interestingHeaders.forEach((entry) => {
      console.log(`  [${entry.direction}] ${entry.name} => ${entry.value}`);
      console.log(`    [${entry.ts}] ${entry.url}`);
    });
  }
  console.log();
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

  if (!options.file) {
    console.error('Missing --file argument.');
    printHelp();
    process.exit(1);
  }

  const absoluteFile = ensureFilePath(process.cwd(), options.file);
  if (!fs.existsSync(absoluteFile)) {
    console.error(`File not found: ${absoluteFile}`);
    process.exit(1);
  }

  const rules = loadRules(process.cwd(), options.rulesPath);
  const hasExplicitFilters =
    options.types.size > 0 ||
    Boolean(options.requestId) ||
    Boolean(options.search) ||
    Boolean(options.regex);
  const collectMatches = hasExplicitFilters;
  const summary = options.summary ? buildSummary(options) : null;
  const matches = [];
  let parseErrors = 0;

  const rl = readline.createInterface({
    input: fs.createReadStream(absoluteFile),
    crlfDelay: Infinity,
  });

  for await (const line of rl) {
    if (!line.trim()) continue;
    let event;
    try {
      event = JSON.parse(line);
    } catch (error) {
      parseErrors += 1;
      continue;
    }

    const classification = classifyEvent(event, rules);

    if (summary) {
      summariseEvent(event, summary, classification);
    }

    if (collectMatches && matches.length < options.limit && matchesFilters(event, options, line, classification)) {
      matches.push({ event, raw: line, classification });
    }
  }

  if (summary) {
    printSummary(summary, options);
  }

  if (parseErrors > 0) {
    console.warn(`[warn] Encountered ${parseErrors} JSON parse errors.`);
  }

  if (!collectMatches) {
    console.log('No explicit filters provided; use --search/--type/--request-id to list concrete events.');
    return;
  }

  if (matches.length === 0) {
    if (options.types.size > 0 || options.search || options.regex || options.requestId) {
      console.log('No events matched the provided filters.');
    } else {
      console.log('No events captured.');
    }
    return;
  }

  console.log(`=== Matches (${matches.length}) ===`);
  matches.forEach(({ event, classification }, index) => {
    const parts = [`#${index + 1}`, `[${event.type}]`, event.ts || ''];
    if (classification) {
      parts.push(`score=${classification.score}`);
      if (classification.categories.length > 0) {
        parts.push(`cat=${classification.categories.join(',')}`);
      }
      if (classification.isNoise) {
        parts.push('[noise]');
      }
    }
    console.log(parts.filter(Boolean).join(' '));
    if (event.url) {
      console.log(`  url: ${event.url}`);
    }
    if (event.method) {
      console.log(`  method: ${event.method}`);
    }
    if (event.resourceType) {
      console.log(`  resourceType: ${event.resourceType}`);
    }
    if (event.status !== undefined) {
      console.log(`  status: ${event.status}`);
    }
    if (event.direction) {
      console.log(`  direction: ${event.direction}`);
    }
    if (event.requestId) {
      console.log(`  requestId: ${event.requestId}`);
    }
    if (event.failureReason) {
      console.log(`  failure: ${event.failureReason}`);
    }
    if (options.showBodies) {
      if (event.postData) {
        console.log(`  postData: ${event.postData}`);
      }
      if (event.body) {
        console.log(`  body: ${event.body}`);
      }
      if (event.payload) {
        console.log(`  payload: ${event.payload}`);
      }
      if (event.text) {
        console.log(`  text: ${event.text}`);
      }
      if (event.message) {
        console.log(`  message: ${event.message}`);
      }
    }
  });
}

main(process.argv.slice(2)).catch((error) => {
  console.error('Analyzer failed:', error);
  process.exit(1);
});
