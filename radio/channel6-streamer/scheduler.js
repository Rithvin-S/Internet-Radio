const EventEmitter = require('events');

/**
 * Scheduler manages track selection, playlist queues, and the authoritative playback timeline.
 */
class Scheduler extends EventEmitter {
  constructor(musicLibrary, options = {}) {
    super();
    this.library = musicLibrary;
    this.mode = options.mode || 'shuffle'; // 'shuffle' | 'playlist'
    this.currentTrack = null;
    this.nextTrack = null;
    this.startTime = 0; // Epoch ms
    this.history = [];  // Last played tracks
    this.queue = [];    // Priority queue of track IDs
    this.customPlaylist = []; // Custom playlist track IDs
    this.customPlaylistIndex = 0;
    this.shufflePool = [];
    this.lastPlayedId = null;

    // Refresh pool if library updates
    this.library.on('scanned', () => {
      this._onLibraryUpdated();
    });
  }

  /**
   * Initializes playback and selects the initial and next tracks
   */
  start() {
    const tracks = this.library.getAllTracks();
    if (tracks.length === 0) {
      console.warn('[Scheduler] Warning: Starting scheduler with empty music library.');
      this.currentTrack = null;
      this.nextTrack = null;
      this.startTime = Date.now();
      return;
    }

    this._refillShufflePool();
    this.currentTrack = this._pickNext();
    this.startTime = Date.now();
    this.lastPlayedId = this.currentTrack ? this.currentTrack.id : null;
    this.nextTrack = this._peekNext();

    console.log(`[Scheduler] Initial track: "${this.currentTrack.title}" by ${this.currentTrack.artist} (${this.currentTrack.durationFormatted})`);
    if (this.nextTrack) {
      console.log(`[Scheduler] Next up: "${this.nextTrack.title}" by ${this.nextTrack.artist} (${this.nextTrack.durationFormatted})`);
    }

    this.emit('trackChange', {
      currentTrack: this.currentTrack,
      startTime: this.startTime,
      nextTrack: this.nextTrack
    });
  }

  /**
   * Advances the playback timeline to the next scheduled song
   */
  advance() {
    if (this.currentTrack) {
      this.history.unshift({
        ...this.currentTrack,
        playedAt: this.startTime
      });
      if (this.history.length > 20) this.history.pop();
    }

    this.currentTrack = this.nextTrack || this._pickNext();
    this.startTime = Date.now();
    this.lastPlayedId = this.currentTrack ? this.currentTrack.id : null;
    this.nextTrack = this._peekNext();

    if (this.currentTrack) {
      console.log(`[Scheduler] Advanced to: "${this.currentTrack.title}" by ${this.currentTrack.artist} (${this.currentTrack.durationFormatted})`);
    }
    if (this.nextTrack) {
      console.log(`[Scheduler] Next up: "${this.nextTrack.title}" by ${this.nextTrack.artist} (${this.nextTrack.durationFormatted})`);
    }

    this.emit('trackChange', {
      currentTrack: this.currentTrack,
      startTime: this.startTime,
      nextTrack: this.nextTrack
    });

    return this.currentTrack;
  }

  /**
   * Picks the next track based on queue, playlist or shuffle mode
   */
  _pickNext() {
    // 1. Check priority queue
    if (this.queue.length > 0) {
      const queuedId = this.queue.shift();
      const track = this.library.getTrack(queuedId);
      if (track) return track;
    }

    // 2. Custom playlist mode
    if (this.mode === 'playlist' && this.customPlaylist.length > 0) {
      const trackId = this.customPlaylist[this.customPlaylistIndex % this.customPlaylist.length];
      this.customPlaylistIndex++;
      const track = this.library.getTrack(trackId);
      if (track) return track;
    }

    // 3. Shuffle mode with consecutive repeat prevention
    const allTracks = this.library.getAllTracks();
    if (allTracks.length === 0) return null;
    if (allTracks.length === 1) return allTracks[0];

    if (this.shufflePool.length === 0) {
      this._refillShufflePool();
    }

    // Ensure first track of new pool is not the one just played
    if (this.shufflePool.length > 1 && this.shufflePool[0].id === this.lastPlayedId) {
      const swapIdx = 1 + Math.floor(Math.random() * (this.shufflePool.length - 1));
      const temp = this.shufflePool[0];
      this.shufflePool[0] = this.shufflePool[swapIdx];
      this.shufflePool[swapIdx] = temp;
    }

    return this.shufflePool.shift() || allTracks[0];
  }

  /**
   * Peeks at what the next track will be without removing it from queue
   */
  _peekNext() {
    if (this.queue.length > 0) {
      return this.library.getTrack(this.queue[0]);
    }
    if (this.mode === 'playlist' && this.customPlaylist.length > 0) {
      const trackId = this.customPlaylist[this.customPlaylistIndex % this.customPlaylist.length];
      return this.library.getTrack(trackId);
    }
    if (this.shufflePool.length > 0) {
      return this.shufflePool[0];
    }
    const all = this.library.getAllTracks();
    if (all.length > 1) {
      const candidate = all.find(t => t.id !== this.lastPlayedId);
      return candidate || all[0];
    }
    return all[0] || null;
  }

  _refillShufflePool() {
    const all = this.library.getAllTracks();
    const copy = [...all];
    // Fisher-Yates shuffle
    for (let i = copy.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [copy[i], copy[j]] = [copy[j], copy[i]];
    }
    this.shufflePool = copy;
  }

  _onLibraryUpdated() {
    if (!this.currentTrack && this.library.getTrackCount() > 0) {
      this.start();
    } else {
      this._refillShufflePool();
      if (!this.nextTrack || !this.library.getTrack(this.nextTrack.id)) {
        this.nextTrack = this._peekNext();
      }
    }
  }

  /**
   * Enqueues a specific track to play next
   */
  enqueueTrack(trackId) {
    const track = this.library.getTrack(trackId);
    if (!track) return false;
    this.queue.push(trackId);
    this.nextTrack = this._peekNext();
    console.log(`[Scheduler] Enqueued track: "${track.title}" by ${track.artist}`);
    return true;
  }

  /**
   * Sets custom playlist ordering
   */
  setPlaylist(trackIds) {
    this.customPlaylist = trackIds.filter(id => !!this.library.getTrack(id));
    this.customPlaylistIndex = 0;
    this.mode = 'playlist';
    this.nextTrack = this._peekNext();
    console.log(`[Scheduler] Set custom playlist with ${this.customPlaylist.length} track(s).`);
  }

  setMode(mode) {
    if (mode === 'shuffle' || mode === 'playlist') {
      this.mode = mode;
      this.nextTrack = this._peekNext();
    }
  }

  /**
   * Skips current track immediately
   */
  skip() {
    console.log('[Scheduler] Skip requested.');
    return this.advance();
  }

  getElapsedSeconds() {
    if (!this.startTime) return 0;
    return Math.max(0, (Date.now() - this.startTime) / 1000);
  }

  getRemainingSeconds() {
    if (!this.currentTrack) return 0;
    return Math.max(0, this.currentTrack.durationSeconds - this.getElapsedSeconds());
  }

  getTimeline() {
    const elapsed = this.getElapsedSeconds();
    const duration = this.currentTrack ? this.currentTrack.durationSeconds : 0;
    const remaining = Math.max(0, duration - elapsed);

    return {
      currentTrack: this.currentTrack ? {
        id: this.currentTrack.id,
        title: this.currentTrack.title,
        artist: this.currentTrack.artist,
        album: this.currentTrack.album,
        durationSeconds: this.currentTrack.durationSeconds,
        durationFormatted: this.currentTrack.durationFormatted,
        bitrateKbps: this.currentTrack.bitrateKbps,
        sampleRateHz: this.currentTrack.sampleRateHz
      } : null,
      startTime: this.startTime,
      startedAtIso: this.startTime ? new Date(this.startTime).toISOString() : null,
      elapsedSeconds: Math.round(elapsed * 10) / 10,
      elapsedFormatted: this.library._formatDuration(elapsed),
      remainingSeconds: Math.round(remaining * 10) / 10,
      remainingFormatted: this.library._formatDuration(remaining),
      nextTrack: this.nextTrack ? {
        id: this.nextTrack.id,
        title: this.nextTrack.title,
        artist: this.nextTrack.artist,
        album: this.nextTrack.album,
        durationSeconds: this.nextTrack.durationSeconds,
        durationFormatted: this.nextTrack.durationFormatted
      } : null,
      mode: this.mode,
      queueCount: this.queue.length,
      history: this.history.slice(0, 5).map(h => ({
        title: h.title,
        artist: h.artist,
        playedAt: new Date(h.playedAt).toISOString()
      }))
    };
  }
}

module.exports = Scheduler;

