const http = require('http');
const https = require('https');
const crypto = require('crypto');
const MusicLibrary = require('./music-library');
const Scheduler = require('./scheduler');
const Broadcaster = require('./broadcaster');

const PORT = parseInt(process.env.CHANNEL6_PORT || process.env.PORT || '8000', 10);
const HOST = process.env.HOST || '0.0.0.0';
const MUSIC_DIR = process.env.MUSIC_DIR;
const AUTH_API_URL = (
  process.env.CHANNEL6_AUTH_API_URL ||
  process.env.API_BASE_URL ||
  'https://internet-radio-stream.onrender.com'
).replace(/\/+$/, '');

// Optional local JWT secret (never falls back to hardcoded secrets; delegates to AUTH_API_URL when unset)
const LOCAL_JWT_SECRET = process.env.CHANNEL6_JWT_SECRET || process.env.JWT_SECRET || '';

// Short-lived in-memory cache of SHA-256(token) -> { user, expiresAtMs }
const verifiedAuthCache = new Map();
const AUTH_CACHE_TTL_MS = 60 * 1000;
const AUTH_CACHE_MAX_ENTRIES = 200;

console.log('======================================================');
console.log('       PULSECAST CHANNEL 6 AUDIO STREAMING SERVER     ');
console.log('      Direct HTTP Real-Time Streaming (Icecast-Free)  ');
console.log('======================================================');

const library = new MusicLibrary({ musicDir: MUSIC_DIR });
const scheduler = new Scheduler(library);
const broadcaster = new Broadcaster(scheduler);

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store'
  });
  res.end(JSON.stringify(payload, null, 2));
}

function readJsonBody(req, maxBytes = 64 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];

    req.on('data', chunk => {
      size += chunk.length;
      if (size > maxBytes) {
        const err = new Error('Request payload too large');
        err.statusCode = 413;
        req.destroy();
        reject(err);
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8').trim();
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (_) {
        const err = new Error('Invalid JSON request body');
        err.statusCode = 400;
        reject(err);
      }
    });

    req.on('error', reject);
  });
}

function extractBearerToken(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader || typeof authHeader !== 'string') return null;
  if (!authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  return token.length > 0 ? token : null;
}

function base64UrlToBuffer(str) {
  const padded = str.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((str.length + 3) % 4);
  return Buffer.from(padded, 'base64');
}

function verifyJwtWithSecret(token, secret) {
  const parts = token.split('.');
  if (parts.length !== 3) return null;

  const [headerB64, payloadB64, sigB64] = parts;
  const signingInput = `${headerB64}.${payloadB64}`;

  try {
    const header = JSON.parse(base64UrlToBuffer(headerB64).toString('utf8'));
    if (!header || header.alg !== 'HS256') return null;

    const expectedSig = crypto
      .createHmac('sha256', secret)
      .update(signingInput)
      .digest();
    const providedSig = base64UrlToBuffer(sigB64);

    if (expectedSig.length !== providedSig.length || !crypto.timingSafeEqual(expectedSig, providedSig)) {
      return null;
    }

    const payload = JSON.parse(base64UrlToBuffer(payloadB64).toString('utf8'));
    if (typeof payload.exp === 'number' && payload.exp * 1000 <= Date.now()) {
      return { expired: true };
    }
    return { payload };
  } catch (_) {
    return null;
  }
}

function peekJwtExpMs(token) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = JSON.parse(base64UrlToBuffer(parts[1]).toString('utf8'));
    if (typeof payload.exp === 'number') {
      return payload.exp * 1000;
    }
  } catch (_) { }
  return null;
}

function verifyTokenViaAuthApi(token) {
  return new Promise((resolve) => {
    let target;
    try {
      target = new URL('/api/auth/me', `${AUTH_API_URL}/`);
    } catch (_) {
      resolve({ ok: false, status: 503, message: 'Auth server URL is misconfigured.' });
      return;
    }

    const client = target.protocol === 'https:' ? https : http;
    const req = client.request(
      target,
      {
        method: 'GET',
        timeout: 15000,
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json',
          'User-Agent': 'PulseCast-Channel6-Streamer/1.0'
        }
      },
      (apiRes) => {
        const chunks = [];
        apiRes.on('data', c => chunks.push(c));
        apiRes.on('end', () => {
          const bodyText = Buffer.concat(chunks).toString('utf8');
          if (apiRes.statusCode === 401) {
            resolve({ ok: false, status: 401, message: 'Invalid or expired authentication token.' });
            return;
          }
          if (apiRes.statusCode === 403) {
            resolve({ ok: false, status: 403, message: 'Access denied. Administrator privileges required.' });
            return;
          }
          if (apiRes.statusCode !== 200) {
            resolve({ ok: false, status: 503, message: 'Unable to verify administrator session.' });
            return;
          }
          try {
            const parsed = JSON.parse(bodyText);
            if (parsed && parsed.user) {
              resolve({ ok: true, user: parsed.user });
              return;
            }
          } catch (_) { }
          resolve({ ok: false, status: 503, message: 'Invalid authentication server response.' });
        });
      }
    );

    req.on('timeout', () => {
      req.destroy();
      resolve({ ok: false, status: 503, message: 'Authentication verification timed out.' });
    });

    req.on('error', () => {
      resolve({ ok: false, status: 503, message: 'Unable to reach authentication server.' });
    });

    req.end();
  });
}

async function authorizeAdmin(req) {
  const token = extractBearerToken(req);
  if (!token) {
    return { ok: false, status: 401, message: 'Authentication required. Please sign in as an administrator.' };
  }

  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  const cached = verifiedAuthCache.get(tokenHash);
  if (cached) {
    if (cached.expiresAtMs > Date.now()) {
      const role = String(cached.user.role || '').toLowerCase();
      if (role !== 'admin') {
        return { ok: false, status: 403, message: 'Access denied. Administrator privileges required.' };
      }
      return { ok: true, user: cached.user };
    }
    verifiedAuthCache.delete(tokenHash);
  }

  // Method 1: Local HS256 JWT verification when JWT_SECRET is explicitly configured
  if (LOCAL_JWT_SECRET) {
    const localVerified = verifyJwtWithSecret(token, LOCAL_JWT_SECRET);
    if (localVerified && localVerified.expired) {
      return { ok: false, status: 401, message: 'Session has expired. Please sign in again.' };
    }
    if (!localVerified || !localVerified.payload) {
      return { ok: false, status: 401, message: 'Invalid authentication token.' };
    }
    const role = String(localVerified.payload.role || '').toLowerCase();
    if (role !== 'admin') {
      return { ok: false, status: 403, message: 'Access denied. Administrator privileges required.' };
    }
    return { ok: true, user: localVerified.payload };
  }

  // Method 2: Authoritative verification via PulseCast Auth API (/api/auth/me)
  const remoteResult = await verifyTokenViaAuthApi(token);
  if (!remoteResult.ok) {
    return remoteResult;
  }

  const expMs = peekJwtExpMs(token);
  const now = Date.now();
  const ttlMs = expMs ? Math.min(AUTH_CACHE_TTL_MS, Math.max(0, expMs - now)) : AUTH_CACHE_TTL_MS;
  if (ttlMs > 0) {
    if (verifiedAuthCache.size >= AUTH_CACHE_MAX_ENTRIES) {
      const firstKey = verifiedAuthCache.keys().next().value;
      if (firstKey) verifiedAuthCache.delete(firstKey);
    }
    verifiedAuthCache.set(tokenHash, {
      user: remoteResult.user,
      expiresAtMs: now + ttlMs
    });
  }

  const role = String(remoteResult.user.role || '').toLowerCase();
  if (role !== 'admin') {
    return { ok: false, status: 403, message: 'Access denied. Administrator privileges required.' };
  }

  return { ok: true, user: remoteResult.user };
}

async function requireAdmin(req, res) {
  const auth = await authorizeAdmin(req);
  if (!auth.ok) {
    sendJson(res, auth.status, {
      success: false,
      message: auth.message
    });
    return null;
  }
  return auth.user;
}

// Create HTTP server
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept'
    });
    res.end();
    return;
  }

  // 1. Live Radio Audio Stream Endpoints (public, read-only)
  if (
    pathname === '/pulsecast.mp3' ||
    pathname === '/stream' ||
    pathname === '/channel6.mp3' ||
    pathname === '/live' ||
    pathname === '/'
  ) {
    if (req.method === 'GET' || req.method === 'HEAD') {
      broadcaster.addListener(req, res);
      return;
    }
    sendJson(res, 405, { success: false, message: 'Method not allowed' });
    return;
  }

  // 2. Health & Status (public, read-only)
  if ((pathname === '/health' || pathname === '/status') && req.method === 'GET') {
    sendJson(res, 200, {
      status: 'ok',
      channel: 6,
      stationName: 'PulseCast Radio',
      timeline: scheduler.getTimeline(),
      stats: broadcaster.getStats(),
      libraryCount: library.getTrackCount()
    });
    return;
  }

  // 3. Now Playing Metadata API (public, read-only)
  if (pathname === '/api/now-playing' && req.method === 'GET') {
    const timeline = scheduler.getTimeline();
    sendJson(res, 200, {
      success: true,
      station: 'PulseCast Radio',
      channel: 6,
      playbackMode: timeline.playbackMode,
      playbackModeLabel: timeline.playbackModeLabel,
      currentTrackSource: timeline.currentTrackSource,
      currentTrack: timeline.currentTrack,
      elapsedSeconds: timeline.elapsedSeconds,
      remainingSeconds: timeline.remainingSeconds,
      nextTrack: timeline.nextTrack,
      activeListeners: broadcaster.getListenerCount()
    });
    return;
  }

  // 4. Music Library Tracks API (public, read-only)
  if (pathname === '/api/tracks' && req.method === 'GET') {
    const tracks = library.getAllTracks().map(t => ({
      id: t.id,
      title: t.title,
      artist: t.artist,
      album: t.album,
      durationSeconds: t.durationSeconds,
      durationFormatted: t.durationFormatted,
      bitrateKbps: t.bitrateKbps,
      fileSize: t.fileSize
    }));
    sendJson(res, 200, { success: true, count: tracks.length, tracks });
    return;
  }

  // 5. Protected Admin Up Next Queue Management Endpoints
  // 5a. Fetch full queue state (currently playing, next up, waiting queue, local library, active mode)
  if ((pathname === '/api/admin/channel6/queue' ||
       pathname === '/api/admin/channel6/schedule' ||
       pathname === '/api/admin/queue') && req.method === 'GET') {
    const admin = await requireAdmin(req, res);
    if (!admin) return;
    sendJson(res, 200, scheduler.getAdminQueueState());
    return;
  }

  // 5b. Fetch indexed local music library tracks
  if (pathname === '/api/admin/channel6/tracks' && req.method === 'GET') {
    const admin = await requireAdmin(req, res);
    if (!admin) return;
    const tracks = library.getAllTracks().map(t => ({
      id: t.id,
      title: t.title,
      artist: t.artist,
      album: t.album,
      durationSeconds: t.durationSeconds,
      durationFormatted: t.durationFormatted,
      bitrateKbps: t.bitrateKbps,
      fileSize: t.fileSize
    }));
    sendJson(res, 200, { success: true, count: tracks.length, tracks });
    return;
  }

  // 5c. Add song(s) to admin playback queue (never interrupts current playing song)
  if ((pathname === '/api/admin/channel6/queue' || pathname === '/api/admin/queue') && req.method === 'POST') {
    const admin = await requireAdmin(req, res);
    if (!admin) return;

    try {
      const body = await readJsonBody(req);
      let result;
      if (Array.isArray(body.trackIds)) {
        result = scheduler.enqueueAdminTracks(body.trackIds);
      } else {
        result = scheduler.enqueueAdminTrack(body.trackId, { position: body.position });
      }

      if (!result.ok) {
        sendJson(res, result.status || 400, { success: false, message: result.error });
        return;
      }

      sendJson(res, 201, {
        ...scheduler.getAdminQueueState(),
        message: 'Added song(s) to Channel 6 Up Next queue without interrupting playback.'
      });
    } catch (err) {
      sendJson(res, err.statusCode || 400, { success: false, message: err.message });
    }
    return;
  }

  // 5d. Reorder pending queue items (drag-and-drop or move-up / move-down)
  if ((pathname === '/api/admin/channel6/queue/reorder' || pathname === '/api/admin/queue/reorder') &&
      (req.method === 'PUT' || req.method === 'POST' || req.method === 'PATCH')) {
    const admin = await requireAdmin(req, res);
    if (!admin) return;

    try {
      const body = await readJsonBody(req);
      const result = scheduler.reorderQueue({
        orderedItemIds: body.orderedItemIds,
        itemId: body.itemId,
        newIndex: body.newIndex
      });

      if (!result.ok) {
        sendJson(res, result.status || 400, { success: false, message: result.error });
        return;
      }

      sendJson(res, 200, scheduler.getAdminQueueState());
    } catch (err) {
      sendJson(res, err.statusCode || 400, { success: false, message: err.message });
    }
    return;
  }

  // 5e. Clear entire pending admin queue (switches back to Automatic Fallback after current song finishes)
  if ((pathname === '/api/admin/channel6/queue' || pathname === '/api/admin/queue') && req.method === 'DELETE') {
    const admin = await requireAdmin(req, res);
    if (!admin) return;

    const result = scheduler.clearQueue();
    sendJson(res, 200, {
      ...scheduler.getAdminQueueState(),
      clearedCount: result.clearedCount
    });
    return;
  }

  // 5f. Remove individual song from pending queue by itemId
  const deleteItemMatch = pathname.match(/^\/api\/admin\/(?:channel6\/)?queue\/([^/]+)$/);
  if (deleteItemMatch && req.method === 'DELETE') {
    const admin = await requireAdmin(req, res);
    if (!admin) return;

    const itemId = decodeURIComponent(deleteItemMatch[1]);
    const result = scheduler.removeQueueItem(itemId);
    if (!result.ok) {
      sendJson(res, result.status || 404, { success: false, message: result.error });
      return;
    }

    sendJson(res, 200, scheduler.getAdminQueueState());
    return;
  }

  // 5g. Admin-protected Rescan Library Action
  if ((pathname === '/api/admin/channel6/rescan' || pathname === '/api/rescan') && req.method === 'POST') {
    const admin = await requireAdmin(req, res);
    if (!admin) return;

    const tracks = await library.scan();
    sendJson(res, 200, {
      ...scheduler.getAdminQueueState(),
      message: 'Rescanned local music folder',
      trackCount: tracks.length
    });
    return;
  }

  // 5h. Admin-protected Skip Track Action (kept POST-only and admin-authorized)
  if ((pathname === '/api/admin/channel6/skip' || pathname === '/api/skip') && req.method === 'POST') {
    const admin = await requireAdmin(req, res);
    if (!admin) return;

    const next = scheduler.skip();
    sendJson(res, 200, {
      success: true,
      message: 'Skipped to next track',
      currentTrack: next ? { id: next.id, title: next.title, artist: next.artist } : null
    });
    return;
  }

  // 404 for unknown routes
  sendJson(res, 404, { error: 'Not Found', path: pathname });
});

// Bootstrap server
async function bootstrap() {
  try {
    await library.scan();
    library.startWatching();
    scheduler.start();
    broadcaster.start();

    server.listen(PORT, HOST, () => {
      console.log(`[PulseCast Server] Channel 6 is LIVE!`);
      console.log(`[PulseCast Server] Stream URL:      http://localhost:${PORT}/pulsecast.mp3`);
      console.log(`[PulseCast Server] Health URL:      http://localhost:${PORT}/health`);
      console.log(`[PulseCast Server] Now-Playing:     http://localhost:${PORT}/api/now-playing`);
      console.log(`[PulseCast Server] Admin Schedule:  http://localhost:${PORT}/api/admin/channel6/schedule`);
    });
  } catch (err) {
    console.error('[PulseCast Server] Fatal startup error:', err);
    process.exit(1);
  }
}

// Graceful termination
function shutdown(signal) {
  console.log(`\n[PulseCast Server] Received ${signal}, shutting down gracefully...`);
  broadcaster.stop();
  library.stopWatching();
  server.close(() => {
    console.log('[PulseCast Server] HTTP server closed. Goodbye!');
    process.exit(0);
  });
  setTimeout(() => process.exit(0), 2000);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

bootstrap();
