const fs = require('fs');
const EventEmitter = require('events');

/**
 * Broadcaster delivers real-time audio chunks to HTTP listeners without Icecast.
 * - Single authoritative playback pacing loop
 * - Memory efficient: reads chunks from disk at current playback position
 * - Listeners joining midway receive current playback position + small priming pre-buffer
 * - Seamless track-to-track transitions on persistent HTTP responses
 * - Non-blocking broadcasts: client disconnects or network lag never affects others
 */
class Broadcaster extends EventEmitter {
  constructor(scheduler, options = {}) {
    super();
    this.scheduler = scheduler;
    this.tickIntervalMs = options.tickIntervalMs || 100; // Broadcast tick every 100ms
    this.listeners = new Set();
    this.currentFd = null;
    this.currentTrackId = null;
    this.currentBytePos = 0;
    this.timer = null;
    this.isRunning = false;

    // Rolling pre-buffer of recent audio frames (e.g. ~96KB, 4s at 192kbps) for instant playback startup & proxy flush
    this.preBufferMaxBytes = 96 * 1024;
    this.preBufferChunks = [];
    this.preBufferTotalBytes = 0;

    // Stats
    this.stats = {
      bytesStreamed: 0,
      totalListenersEver: 0,
      peakConcurrentListeners: 0,
      startTime: 0
    };

    // Pre-allocated silent frame for empty library fallback
    this.silentFrame = this._createSilentFrame();
  }

  _createSilentFrame() {
    const frame = Buffer.alloc(417, 0);
    frame[0] = 0xFF;
    frame[1] = 0xFB; // MPEG-1, Layer 3, no CRC
    frame[2] = 0x90; // 128 kbps, 44100 Hz, no padding
    frame[3] = 0x64; // Joint stereo
    return frame;
  }

  /**
   * Starts the broadcast engine loop
   */
  start() {
    if (this.isRunning) return;
    this.isRunning = true;
    this.stats.startTime = Date.now();
    this._openCurrentTrackFile();

    this.timer = setInterval(() => {
      this._onTick();
    }, this.tickIntervalMs);

    console.log(`[Broadcaster] Real-time audio engine started (interval: ${this.tickIntervalMs}ms).`);
  }

  /**
   * Stops the broadcast engine and closes open files
   */
  stop() {
    if (!this.isRunning) return;
    this.isRunning = false;
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    this._closeCurrentTrackFile();

    // Close all listener sockets
    for (const res of this.listeners) {
      try {
        res.end();
      } catch (_) { }
    }
    this.listeners.clear();
    console.log('[Broadcaster] Real-time audio engine stopped.');
  }

  /**
   * Attaches a new HTTP response listener to the live broadcast
   */
  addListener(req, res) {
    this.stats.totalListenersEver++;
    const currentTrack = this.scheduler.currentTrack;
    const bitrate = currentTrack ? currentTrack.bitrateKbps : 192;
    const sampleRate = currentTrack ? (currentTrack.sampleRate || currentTrack.sampleRateHz || 44100) : 44100;

    // Send streaming HTTP response headers compatible with just_audio / ExoPlayer / AVPlayer / curl / browser
    res.writeHead(200, {
      'Content-Type': 'audio/mpeg',
      'Transfer-Encoding': 'chunked',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache, no-store, must-revalidate, no-transform',
      'Pragma': 'no-cache',
      'Expires': '0',
      'X-Accel-Buffering': 'no',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': '*',
      'X-Content-Type-Options': 'nosniff',
      'Accept-Ranges': 'none',
      'icy-name': 'PulseCast Radio',
      'icy-description': 'PulseCast Channel 6 Automated Radio',
      'icy-genre': 'Mixed',
      'icy-pub': '1',
      'icy-br': String(bitrate),
      'ice-audio-info': `channels=2;samplerate=${sampleRate};bitrate=${bitrate}`
    });

    // 1. Send recent pre-buffer to instantly prime client decoder buffer
    if (this.preBufferChunks.length > 0) {
      try {
        for (const chunk of this.preBufferChunks) {
          res.write(chunk);
        }
      } catch (err) {
        res.destroy();
        return;
      }
    }

    // 2. Register into active listener set
    this.listeners.add(res);
    if (this.listeners.size > this.stats.peakConcurrentListeners) {
      this.stats.peakConcurrentListeners = this.listeners.size;
    }

    const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
    console.log(`[Broadcaster] + Listener connected from ${clientIp}. Total active: ${this.listeners.size}`);

    // 3. Clean disconnect handling
    const cleanup = () => {
      if (this.listeners.delete(res)) {
        console.log(`[Broadcaster] - Listener disconnected. Remaining active: ${this.listeners.size}`);
      }
    };

    req.on('close', cleanup);
    res.on('close', cleanup);
    res.on('error', cleanup);
    res.on('finish', cleanup);
  }

  removeListener(res) {
    if (this.listeners.delete(res)) {
      try {
        res.end();
      } catch (_) { }
    }
  }

  /**
   * Main pacing loop: executes every tickIntervalMs
   */
  _onTick() {
    const track = this.scheduler.currentTrack;

    if (!track) {
      // Empty music library fallback: broadcast silent frames
      this._broadcastChunk(this.silentFrame);
      return;
    }

    // Check if current track needs to advance
    const elapsedSeconds = this.scheduler.getElapsedSeconds();
    if (elapsedSeconds >= track.durationSeconds) {
      this._advanceTrack();
      return;
    }

    // Ensure file is open
    if (!this.currentFd || this.currentTrackId !== track.id) {
      this._openCurrentTrackFile();
    }

    if (!this.currentFd) {
      this._broadcastChunk(this.silentFrame);
      return;
    }

    // Calculate target byte position according to real-time playback timeline
    const targetOffset = track.audioStart + Math.min(
      track.audioBytes,
      Math.floor(elapsedSeconds * track.byteRate)
    );

    if (targetOffset <= this.currentBytePos) {
      // Caught up to current timeline, wait for next tick
      return;
    }

    // Read bytes from file (capped to max 16KB per tick to prevent bursts)
    const bytesToRead = Math.min(16384, targetOffset - this.currentBytePos);
    if (bytesToRead <= 0) return;

    const chunk = Buffer.alloc(bytesToRead);
    try {
      const bytesRead = fs.readSync(this.currentFd, chunk, 0, bytesToRead, this.currentBytePos);
      if (bytesRead > 0) {
        const actualChunk = bytesRead === bytesToRead ? chunk : chunk.subarray(0, bytesRead);
        this.currentBytePos += bytesRead;
        this._broadcastChunk(actualChunk);
      }
    } catch (err) {
      console.error(`[Broadcaster] Read error for "${track.title}":`, err.message);
      this._advanceTrack();
    }
  }

  /**
   * Broadcasts audio chunk to all active listeners and updates rolling pre-buffer
   */
  _broadcastChunk(chunk) {
    if (!chunk || chunk.length === 0) return;

    this.stats.bytesStreamed += chunk.length;

    // Update rolling pre-buffer
    this.preBufferChunks.push(chunk);
    this.preBufferTotalBytes += chunk.length;
    while (this.preBufferTotalBytes > this.preBufferMaxBytes && this.preBufferChunks.length > 1) {
      const removed = this.preBufferChunks.shift();
      this.preBufferTotalBytes -= removed.length;
    }

    // If no listeners connected, audio continues playing on the timeline
    if (this.listeners.size === 0) return;

    // Write to each connected listener safely
    for (const res of this.listeners) {
      if (res.writableEnded || res.destroyed) {
        this.listeners.delete(res);
        continue;
      }

      try {
        const canWriteMore = res.write(chunk);
        if (!canWriteMore && res.writableLength > 2 * 1024 * 1024) {
          // Socket buffer backlog exceeds 2MB (stalled or unconsuming client)
          console.warn('[Broadcaster] Listener buffer overflow (>2MB), closing stalled socket.');
          res.destroy();
          this.listeners.delete(res);
        }
      } catch (err) {
        this.listeners.delete(res);
      }
    }
  }

  _advanceTrack() {
    this._closeCurrentTrackFile();
    const nextTrack = this.scheduler.advance();
    if (nextTrack) {
      this._openCurrentTrackFile();
    }
  }

  _openCurrentTrackFile() {
    this._closeCurrentTrackFile();
    const track = this.scheduler.currentTrack;
    if (!track) return;

    try {
      this.currentFd = fs.openSync(track.filePath, 'r');
      this.currentTrackId = track.id;
      // Position at current timeline offset
      const elapsed = this.scheduler.getElapsedSeconds();
      this.currentBytePos = track.audioStart + Math.min(
        track.audioBytes,
        Math.floor(elapsed * track.byteRate)
      );
    } catch (err) {
      console.error(`[Broadcaster] Failed to open track file "${track.filePath}":`, err.message);
      this.currentFd = null;
      this.currentTrackId = null;
    }
  }

  _closeCurrentTrackFile() {
    if (this.currentFd !== null) {
      try {
        fs.closeSync(this.currentFd);
      } catch (_) { }
      this.currentFd = null;
      this.currentTrackId = null;
    }
  }

  getListenerCount() {
    return this.listeners.size;
  }

  getStats() {
    return {
      ...this.stats,
      activeListeners: this.listeners.size,
      uptimeSeconds: this.stats.startTime ? Math.floor((Date.now() - this.stats.startTime) / 1000) : 0,
      preBufferBytes: this.preBufferTotalBytes
    };
  }
}

module.exports = Broadcaster;
