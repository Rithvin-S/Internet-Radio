const http = require('http');
const path = require('path');
const MusicLibrary = require('./music-library');
const Scheduler = require('./scheduler');
const Broadcaster = require('./broadcaster');

const PORT = parseInt(process.env.CHANNEL6_PORT || process.env.PORT || '8000', 10);
const HOST = process.env.HOST || '0.0.0.0';
const MUSIC_DIR = process.env.MUSIC_DIR;

console.log('======================================================');
console.log('       PULSECAST CHANNEL 6 AUDIO STREAMING SERVER     ');
console.log('      Direct HTTP Real-Time Streaming (Icecast-Free)  ');
console.log('======================================================');

const library = new MusicLibrary({ musicDir: MUSIC_DIR });
const scheduler = new Scheduler(library);
const broadcaster = new Broadcaster(scheduler);

// Create HTTP server
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': '*'
    });
    res.end();
    return;
  }

  // 1. Live Radio Audio Stream Endpoints
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
  }

  // 2. Health & Status
  if (pathname === '/health' || pathname === '/status') {
    const data = {
      status: 'ok',
      channel: 6,
      stationName: 'PulseCast Radio',
      timeline: scheduler.getTimeline(),
      stats: broadcaster.getStats(),
      libraryCount: library.getTrackCount()
    };
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify(data, null, 2));
    return;
  }

  // 3. Now Playing Metadata API
  if (pathname === '/api/now-playing') {
    const timeline = scheduler.getTimeline();
    const data = {
      success: true,
      station: 'PulseCast Radio',
      channel: 6,
      currentTrack: timeline.currentTrack,
      elapsedSeconds: timeline.elapsedSeconds,
      remainingSeconds: timeline.remainingSeconds,
      nextTrack: timeline.nextTrack,
      activeListeners: broadcaster.getListenerCount()
    };
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify(data, null, 2));
    return;
  }

  // 4. Music Library Tracks API
  if (pathname === '/api/tracks') {
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
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify({ success: true, count: tracks.length, tracks }, null, 2));
    return;
  }

  // 5. Skip Track Action
  if (pathname === '/api/skip' && (req.method === 'POST' || req.method === 'GET')) {
    const next = scheduler.skip();
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify({
      success: true,
      message: 'Skipped to next track',
      currentTrack: next ? { title: next.title, artist: next.artist } : null
    }));
    return;
  }

  // 6. Rescan Library Action
  if (pathname === '/api/rescan' && (req.method === 'POST' || req.method === 'GET')) {
    library.scan().then(tracks => {
      res.writeHead(200, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      });
      res.end(JSON.stringify({
        success: true,
        message: 'Rescanned library',
        trackCount: tracks.length
      }));
    });
    return;
  }

  // 404 for unknown routes
  res.writeHead(404, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
  });
  res.end(JSON.stringify({ error: 'Not Found', path: pathname }));
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
      console.log(`[PulseCast Server] Stream URL:   http://localhost:${PORT}/pulsecast.mp3`);
      console.log(`[PulseCast Server] Health URL:   http://localhost:${PORT}/health`);
      console.log(`[PulseCast Server] Now-Playing:  http://localhost:${PORT}/api/now-playing`);
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

