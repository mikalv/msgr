#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { mkdir, readFile } = require('fs/promises');
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const {
  decodeBodyContent,
  getHeaderValue,
  createOnceLogger,
  decompressBodyContent,
  persistResourceToDisk,
  maybeBeautifyResource,
} = require('./resource_utils');

const CAPTURE_DIR = path.join(__dirname, '..', 'captures');
const CAMOUFLAGE_PROFILES = [
  {
    id: 'macos-sonoma',
    userAgent:
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_6_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    acceptLanguage: 'en-US,en;q=0.9',
    languages: ['en-US', 'en'],
    platform: 'MacIntel',
    hardwareConcurrency: 8,
    deviceMemory: 8,
    maxTouchPoints: 1,
    timezone: 'America/Los_Angeles',
    viewport: { width: 1440, height: 900, deviceScaleFactor: 2 },
  },
  {
    id: 'windows-11',
    userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    acceptLanguage: 'en-US,en;q=0.9',
    languages: ['en-US', 'en'],
    platform: 'Win32',
    hardwareConcurrency: 12,
    deviceMemory: 16,
    maxTouchPoints: 1,
    timezone: 'America/New_York',
    viewport: { width: 1920, height: 1080, deviceScaleFactor: 1 },
  },
  {
    id: 'linux-workstation',
    userAgent:
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    acceptLanguage: 'en-GB,en;q=0.8',
    languages: ['en-GB', 'en'],
    platform: 'Linux x86_64',
    hardwareConcurrency: 8,
    deviceMemory: 8,
    maxTouchPoints: 0,
    timezone: 'Europe/London',
    viewport: { width: 1680, height: 1050, deviceScaleFactor: 1 },
  },
];

function printHelp() {
  const content = `
Chrome-based recorder for intercepting the official client traffic.

Usage:
  npm run record -- --url <https://client.example> [options]
  client-recorder --url <https://client.example> [options]

Options:
  --url <string>            Target URL to open (required)
  --headless                Run Chrome in headless mode (default: UI mode)
  --no-headless             Force UI mode even if HEADLESS env is set
  --script <path>           Inject and run a JavaScript automation file after load
  --output <path>           Custom output file (default: captures/session-<timestamp>.jsonl)
  --executable <path>       Custom Chrome / Chromium binary path
  --capture-bodies          Persist HTTP response bodies and WebSocket payloads
  --save-resources          Write decoded HTTP responses to disk for offline inspection
  --no-save-resources       Disable resource persistence even if enabled elsewhere
  --resources-dir <path>    Directory for saved resources (default: derived from --output)
  --no-pretty-resources     Skip generating prettified text/JSON companions for saved resources
  --slowmo <ms>             Slow Puppeteer actions by the given milliseconds
  --devtools                Open DevTools automatically (only in non-headless mode)
  --stealth                 Enable stealth evasion (default: on)
  --no-stealth              Disable stealth evasion tweaks
  --no-camouflage           Skip navigator/user-agent spoofing
  --camouflage-profile <id> Use a specific camouflage profile (default: random)
  --chrome-arg <value>      Extra launch argument (repeatable)
  -h, --help                Show this help message
`.trim();
  console.log(content);
}

function parseArgs(argv) {
  const options = {
    headless: false,
    captureBodies: false,
    saveResources: false,
    resourcesDir: null,
    beautifyResources: true,
    chromeArgs: [],
    slowMo: 0,
    stealth: true,
    camouflage: true,
  };

  const args = [...argv];
  while (args.length > 0) {
    const arg = args.shift();
    switch (arg) {
      case '--headless':
        options.headless = true;
        break;
      case '--no-headless':
        options.headless = false;
        break;
      case '--capture-bodies':
        options.captureBodies = true;
        break;
      case '--save-resources':
        options.saveResources = true;
        break;
      case '--no-save-resources':
        options.saveResources = false;
        break;
      case '--resources-dir':
        options.resourcesDir = args.shift();
        break;
      case '--no-pretty-resources':
        options.beautifyResources = false;
        break;
      case '--devtools':
        options.devtools = true;
        break;
      case '--stealth':
        options.stealth = true;
        break;
      case '--no-stealth':
        options.stealth = false;
        break;
      case '--no-camouflage':
        options.camouflage = false;
        break;
      case '--camouflage-profile':
        options.camouflageProfile = args.shift();
        break;
      case '-h':
      case '--help':
        options.help = true;
        break;
      case '--url':
        options.url = args.shift();
        break;
      case '--script':
        options.script = args.shift();
        break;
      case '--output':
        options.output = args.shift();
        break;
      case '--executable':
        options.executable = args.shift();
        break;
      case '--slowmo':
        {
          const value = args.shift();
          const parsed = Number.parseInt(value, 10);
          if (Number.isNaN(parsed)) {
            throw new Error(`Invalid --slowmo value: ${value}`);
          }
          options.slowMo = parsed;
        }
        break;
      case '--chrome-arg':
        options.chromeArgs.push(args.shift());
        break;
      default:
        if (arg.startsWith('--slowmo=')) {
          const [, value] = arg.split('=');
          const parsed = Number.parseInt(value, 10);
          if (Number.isNaN(parsed)) {
            throw new Error(`Invalid --slowmo value: ${value}`);
          }
          options.slowMo = parsed;
        } else if (arg.startsWith('--chrome-arg=')) {
          const [, value] = arg.split('=');
          options.chromeArgs.push(value);
        } else if (arg.startsWith('--output=')) {
          const [, value] = arg.split('=');
          options.output = value;
        } else if (arg.startsWith('--url=')) {
          const [, value] = arg.split('=');
          options.url = value;
        } else if (arg.startsWith('--script=')) {
          const [, value] = arg.split('=');
          options.script = value;
        } else if (arg.startsWith('--executable=')) {
          const [, value] = arg.split('=');
          options.executable = value;
        } else if (arg.startsWith('--resources-dir=')) {
          const [, value] = arg.split('=');
          options.resourcesDir = value;
        } else if (arg.startsWith('--camouflage-profile=')) {
          const [, value] = arg.split('=');
          options.camouflageProfile = value;
        } else {
          throw new Error(`Unknown argument: ${arg}`);
        }
    }
  }

  if (process.env.HEADLESS?.toLowerCase() === 'true' && options.headless === false) {
    options.headless = true;
  }

  return options;
}

function nowIso() {
  return new Date().toISOString();
}

function formatWallTime(wallTimeSeconds) {
  if (typeof wallTimeSeconds === 'number') {
    return new Date(wallTimeSeconds * 1000).toISOString();
  }
  return nowIso();
}

function resolveOutputPath(customPath) {
  if (customPath) {
    return path.isAbsolute(customPath)
      ? customPath
      : path.join(process.cwd(), customPath);
  }
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  return path.join(CAPTURE_DIR, `session-${stamp}.jsonl`);
}

function resolveResourceDirectory(customPath, outputPath) {
  if (customPath) {
    return path.isAbsolute(customPath)
      ? customPath
      : path.join(process.cwd(), customPath);
  }
  const outputDir = path.dirname(outputPath);
  const baseName = path.basename(outputPath, path.extname(outputPath));
  return path.join(outputDir, `${baseName}_resources`);
}

function pickCamouflageProfile(requestedId) {
  if (CAMOUFLAGE_PROFILES.length === 0) {
    return null;
  }

  if (requestedId) {
    const normalized = requestedId.trim().toLowerCase();
    const match = CAMOUFLAGE_PROFILES.find(
      (profile) => profile.id.toLowerCase() === normalized,
    );
    if (match) {
      return match;
    }
    console.warn(
      `[Recorder] Unknown camouflage profile "${requestedId}", falling back to random preset.`,
    );
  }

  const index = Math.floor(Math.random() * CAMOUFLAGE_PROFILES.length);
  return CAMOUFLAGE_PROFILES[index];
}

async function applyCamouflage(page, profile) {
  if (!profile) return;

  if (profile.userAgent) {
    await page.setUserAgent(profile.userAgent);
  }

  if (profile.acceptLanguage) {
    await page.setExtraHTTPHeaders({
      'Accept-Language': profile.acceptLanguage,
    });
  }

  if (profile.viewport) {
    try {
      await page.setViewport(profile.viewport);
    } catch (error) {
      console.warn(
        `[Recorder] Unable to apply viewport ${JSON.stringify(profile.viewport)}: ${error.message}`,
      );
    }
  }

  if (profile.timezone) {
    try {
      await page.emulateTimezone(profile.timezone);
    } catch (error) {
      console.warn(
        `[Recorder] Unable to emulate timezone "${profile.timezone}": ${error.message}`,
      );
    }
  }

  await page.evaluateOnNewDocument((config) => {
    const defineGetter = (target, key, value) => {
      try {
        Object.defineProperty(target, key, {
          get: () => value,
          configurable: true,
        });
      } catch (_) {
        // noop: property might be non-configurable in some environments.
      }
    };

    const cloneArray = (input) => (Array.isArray(input) ? input.slice() : input);

    if (config.languages && config.languages.length) {
      defineGetter(navigator, 'languages', cloneArray(config.languages));
      defineGetter(navigator, 'language', config.languages[0]);
    }

    if (config.platform) {
      defineGetter(navigator, 'platform', config.platform);
    }

    if (typeof config.hardwareConcurrency === 'number') {
      defineGetter(navigator, 'hardwareConcurrency', config.hardwareConcurrency);
    }

    if (typeof config.deviceMemory === 'number') {
      defineGetter(navigator, 'deviceMemory', config.deviceMemory);
    }

    if (typeof config.maxTouchPoints === 'number') {
      defineGetter(navigator, 'maxTouchPoints', config.maxTouchPoints);
    }

    defineGetter(navigator, 'webdriver', undefined);

    if (!window.chrome) {
      Object.defineProperty(window, 'chrome', {
        value: { app: {}, runtime: {}, loadTimes: () => {}, csi: () => {} },
        configurable: true,
      });
    }

    if (!navigator.plugins || navigator.plugins.length === 0) {
      const fakePlugins = [
        {
          name: 'Chrome PDF Plugin',
          filename: 'internal-pdf-viewer',
          description: 'Portable Document Format',
        },
        {
          name: 'Chrome PDF Viewer',
          filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai',
          description: '',
        },
        {
          name: 'Native Client',
          filename: 'internal-nacl-plugin',
          description: '',
        },
      ];
      defineGetter(navigator, 'plugins', fakePlugins);
    }

    const { permissions } = navigator;
    if (permissions && typeof permissions.query === 'function') {
      const originalQuery = permissions.query.bind(permissions);
      permissions.query = (parameters) => {
        if (parameters && parameters.name === 'notifications') {
          const state =
            typeof Notification === 'undefined' ? 'default' : Notification.permission;
          return Promise.resolve({ state });
        }
        return originalQuery(parameters);
      };
    }
  }, {
    languages: profile.languages,
    platform: profile.platform,
    hardwareConcurrency: profile.hardwareConcurrency,
    deviceMemory: profile.deviceMemory,
    maxTouchPoints: profile.maxTouchPoints,
  });
}

function createWriter(filePath) {
  const stream = fs.createWriteStream(filePath, { flags: 'a' });
  const write = (payload) => {
    stream.write(`${JSON.stringify(payload)}\n`);
  };
  const close = () =>
    new Promise((resolve) => {
      stream.end(() => resolve());
    });
  return { write, close, stream };
}

async function loadAutomationScript(scriptPath) {
  if (!scriptPath) return null;
  const absolutePath = path.isAbsolute(scriptPath)
    ? scriptPath
    : path.join(process.cwd(), scriptPath);
  return readFile(absolutePath, 'utf8');
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

  if (!options.url) {
    console.error('Missing required --url argument.');
    printHelp();
    process.exit(1);
  }

  if (options.stealth) {
    const alreadyRegistered =
      Array.isArray(puppeteer.plugins) &&
      puppeteer.plugins.some((plugin) => plugin.name === 'stealth');
    if (!alreadyRegistered) {
      puppeteer.use(StealthPlugin());
    }
  } else {
    console.warn(
      '[Recorder] Stealth evasion disabled via flags; automation may be easier to detect.',
    );
  }

  const camouflageProfile =
    options.camouflage !== false
      ? pickCamouflageProfile(options.camouflageProfile)
      : null;
  if (camouflageProfile) {
    console.log(`[Recorder] Using camouflage profile "${camouflageProfile.id}".`);
  }

  const chromeArgs = options.chromeArgs.filter(Boolean);

  const outputPath = resolveOutputPath(options.output);
  const outputDirectory = path.dirname(outputPath);
  await mkdir(outputDirectory, { recursive: true });

  const resourceDir =
    options.saveResources === true
      ? resolveResourceDirectory(options.resourcesDir, outputPath)
      : null;
  if (resourceDir) {
    await mkdir(resourceDir, { recursive: true });
    console.log(`[Recorder] Saving resources under ${resourceDir}`);
  }

  const writer = createWriter(outputPath);
  const resourceDirRelative = resourceDir
    ? path.relative(outputDirectory, resourceDir) || '.'
    : null;
  writer.write({
    type: 'metadata',
    event: 'session-start',
    ts: nowIso(),
    options: {
      url: options.url,
      headless: options.headless,
      captureBodies: options.captureBodies,
      saveResources: options.saveResources,
      beautifyResources: options.beautifyResources,
      slowMo: options.slowMo,
      chromeArgs,
      stealth: Boolean(options.stealth),
      camouflageProfile: camouflageProfile ? camouflageProfile.id : null,
      resourceDir: resourceDirRelative,
    },
  });

  console.log(`[Recorder] Output -> ${outputPath}`);
  const automationSource = await loadAutomationScript(options.script);
  if (automationSource) {
    console.log(`[Recorder] Loaded automation script from ${options.script}`);
  }

  const launchOptions = {
    headless: options.headless ? 'new' : false,
    slowMo: options.slowMo || 0,
    defaultViewport: camouflageProfile?.viewport || null,
    args: chromeArgs,
  };

  if (options.executable) {
    launchOptions.executablePath = options.executable;
  }

  if (options.devtools) {
    launchOptions.devtools = true;
  }

  const browser = await puppeteer.launch(launchOptions);
  const [page] = await browser.pages();
  if (camouflageProfile) {
    await applyCamouflage(page, camouflageProfile);
  }
  const session = await page.target().createCDPSession();
  await session.send('Network.enable');

  const pendingResponses = new Map();
  let resourceCounter = 0;
  const shouldFetchResponseBody = options.captureBodies || options.saveResources;
  const warnDecompressionOnce = createOnceLogger('decompression');

  const writeRequest = (params) => {
    const { requestId, request, wallTime, type, initiator, frameId } = params;
    writer.write({
      type: 'http-request',
      ts: formatWallTime(wallTime),
      requestId,
      url: request.url,
      method: request.method,
      headers: request.headers,
      hasPostData: Boolean(request.postData),
      postData: request.postData || null,
      resourceType: type,
      initiator: initiator ? { type: initiator.type, url: initiator.url } : null,
      frameId,
    });
  };

  const writeResponse = async (requestId, reason = null) => {
    const entry = pendingResponses.get(requestId);
    pendingResponses.delete(requestId);

    if (!entry || !entry.response) {
      if (reason) {
        writer.write({
          type: 'http-failure',
          ts: nowIso(),
          requestId,
          url: entry?.request?.url || null,
          reason,
        });
      }
      return;
    }

    const { response, resourceType } = entry;
    let body = null;
    let base64Encoded = false;
    let resourcePath = null;
    let resourcePrettyPath = null;
    let rawBodyString = null;
    let rawBodyBase64 = false;

    if (shouldFetchResponseBody) {
      try {
        const payload = await session.send('Network.getResponseBody', { requestId });
        rawBodyString = payload.body;
        rawBodyBase64 = payload.base64Encoded;
      } catch (error) {
        rawBodyString = null;
        rawBodyBase64 = false;
        reason = reason || error.message;
      }
    }

    if (rawBodyString != null) {
      if (options.saveResources) {
        const rawBuffer = decodeBodyContent(rawBodyString, rawBodyBase64);
        const encodingHeader = getHeaderValue(response.headers, 'content-encoding');
        const shouldAttemptDecompression =
          Boolean(encodingHeader) && rawBodyBase64 === true;
        const decodedBuffer = shouldAttemptDecompression
          ? decompressBodyContent(rawBuffer, encodingHeader, warnDecompressionOnce)
          : rawBuffer;
        if (decodedBuffer) {
          const currentIndex = ++resourceCounter;
          try {
            const savedPath = await persistResourceToDisk(
              resourceDir,
              response,
              decodedBuffer,
              requestId,
              currentIndex,
            );
            if (savedPath) {
              const relPath = path.relative(outputDirectory, savedPath);
              resourcePath = relPath && relPath !== '' ? relPath : path.basename(savedPath);
              if (options.beautifyResources) {
                const prettyRelPath = await maybeBeautifyResource({
                  buffer: decodedBuffer,
                  response,
                  absolutePath: savedPath,
                  beautifyEnabled: options.beautifyResources,
                  outputDirectory,
                });
                if (prettyRelPath) {
                  resourcePrettyPath = prettyRelPath;
                }
              }
            }
          } catch (error) {
            console.error('[Recorder] Failed to persist resource', error);
          }
        }
      }

      if (options.captureBodies) {
        body = rawBodyString;
        base64Encoded = rawBodyBase64;
      }
    }

    const ts = nowIso();
    writer.write({
      type: 'http-response',
      ts,
      requestId,
      url: response.url,
      status: response.status,
      statusText: response.statusText,
      headers: response.headers,
      mimeType: response.mimeType,
      remoteIPAddress: response.remoteIPAddress || null,
      remotePort: response.remotePort || null,
      fromDiskCache: response.fromDiskCache,
      fromServiceWorker: response.fromServiceWorker,
      encodedDataLength: response.encodedDataLength,
      protocol: response.protocol,
      resourceType,
      timing: response.timing || null,
      body,
      base64Encoded,
      resourcePath,
      resourcePrettyPath,
      failureReason: reason,
    });
  };

  session.on('Network.requestWillBeSent', (params) => {
    if (params.request.url.startsWith('data:')) return;
    if (params.redirectResponse) {
      const redirectEntry = pendingResponses.get(params.requestId) || {};
      redirectEntry.response = params.redirectResponse;
      redirectEntry.resourceType = params.type || redirectEntry.resourceType;
      pendingResponses.set(params.requestId, redirectEntry);
      writeResponse(params.requestId, 'redirect').catch((error) => {
        console.error('[Recorder] Failed to write redirect response', error);
      });
    }
    writeRequest(params);
    const existing = pendingResponses.get(params.requestId) || {};
    pendingResponses.set(params.requestId, {
      ...existing,
      request: params.request,
      requestWallTime: params.wallTime,
      initiator: params.initiator,
      resourceType: params.type || existing.resourceType,
      frameId: params.frameId,
    });
  });

  session.on('Network.responseReceived', (params) => {
    const existing = pendingResponses.get(params.requestId) || {};
    pendingResponses.set(params.requestId, {
      ...existing,
      response: params.response,
      resourceType: params.type || existing.resourceType,
      responseTimestamp: params.timestamp,
    });
  });

  session.on('Network.loadingFinished', ({ requestId }) => {
    writeResponse(requestId).catch((error) => {
      console.error('[Recorder] Failed to write response', error);
    });
  });

  session.on('Network.loadingFailed', ({ requestId, errorText }) => {
    writeResponse(requestId, errorText).catch((error) => {
      console.error('[Recorder] Failed to write failure event', error);
    });
  });

  session.on('Network.webSocketCreated', (params) => {
    writer.write({
      type: 'ws-event',
      event: 'open',
      ts: nowIso(),
      requestId: params.requestId,
      url: params.url,
      initiator: params.initiator || null,
    });
  });

  session.on('Network.webSocketFrameSent', (params) => {
    writer.write({
      type: 'ws-frame',
      direction: 'outgoing',
      ts: nowIso(),
      requestId: params.requestId,
      opcode: params.response.opcode,
      payloadLength: params.response.payloadData.length,
      payload: options.captureBodies ? params.response.payloadData : null,
    });
  });

  session.on('Network.webSocketFrameReceived', (params) => {
    writer.write({
      type: 'ws-frame',
      direction: 'incoming',
      ts: nowIso(),
      requestId: params.requestId,
      opcode: params.response.opcode,
      payloadLength: params.response.payloadData.length,
      payload: options.captureBodies ? params.response.payloadData : null,
    });
  });

  session.on('Network.webSocketFrameError', (params) => {
    writer.write({
      type: 'ws-event',
      event: 'frame-error',
      ts: nowIso(),
      requestId: params.requestId,
      errorMessage: params.errorMessage,
    });
  });

  session.on('Network.webSocketClosed', (params) => {
    writer.write({
      type: 'ws-event',
      event: 'close',
      ts: nowIso(),
      requestId: params.requestId,
    });
  });

  page.on('console', (msg) => {
    writer.write({
      type: 'console',
      ts: nowIso(),
      location: msg.location() || null,
      text: msg.text(),
    });
  });

  page.on('pageerror', (error) => {
    writer.write({
      type: 'page-error',
      ts: nowIso(),
      message: error.message,
      stack: error.stack,
    });
  });

  const cleanup = async (signal) => {
    writer.write({
      type: 'metadata',
      event: 'session-end',
      ts: nowIso(),
      reason: signal || 'completed',
    });
    await writer.close();
    try {
      await browser.close();
    } catch (error) {
      if (!/Target closed/.test(error.message)) {
        console.error('[Recorder] Error while closing browser', error);
      }
    }
  };

  let shuttingDown = false;
  const waitForExit = new Promise((resolve) => {
    const handleExit = async (signal) => {
      if (shuttingDown) return;
      shuttingDown = true;
      try {
        await cleanup(signal);
      } catch (error) {
        console.error('[Recorder] Error during cleanup', error);
      } finally {
        resolve();
        process.exit(0);
      }
    };

    process.on('SIGINT', () => handleExit('SIGINT'));
    process.on('SIGTERM', () => handleExit('SIGTERM'));
    page.on('close', () => handleExit('page-closed'));
  });

  console.log(`[Recorder] Navigating to ${options.url}`);
  await page.goto(options.url, { waitUntil: 'networkidle2' }).catch((error) => {
    console.error(`[Recorder] Failed to navigate: ${error.message}`);
  });

  if (automationSource) {
    console.log('[Recorder] Executing automation script in page context.');
    try {
      await page.evaluate((source) => {
        const runner = new Function(`return (async () => {\n${source}\n})();`);
        return runner();
      }, automationSource);
    } catch (error) {
      console.error(`[Recorder] Automation script failed: ${error.message}`);
      writer.write({
        type: 'automation-error',
        ts: nowIso(),
        message: error.message,
        stack: error.stack,
      });
    }
  }

  console.log('[Recorder] Recording active. Press Ctrl+C to stop.');
  await waitForExit;
}

main(process.argv.slice(2)).catch((error) => {
  console.error('[Recorder] Unhandled error:', error);
  process.exit(1);
});
