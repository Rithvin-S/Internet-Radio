const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const EventEmitter = require('events');

/**
 * Scheduler manages track selection, admin-controlled playback queues,
 * automatic fallback shuffle playback, local persistence, and the authoritative timeline.
 */
class Scheduler extends EventEmitter {
  constructor(musicLibrary, options = {}) {
    super();
    this.library = musicLibrary;
    this.mode = options.mode || 'shuffle'; // legacy playlist support ('shuffle' | 'playlist')
    this.currentTrack = null;
    this.nextTrack = null;
    this.currentTrackSource = 'fallback_shuffle'; // 'admin_schedule' | 'custom_playlist' | 'fallback_shuffle'
    this.nextTrackSource = 'fallback_shuffle';
    this.startTime = 0; // Epoch ms
    this.history = [];  // Last played tracks
    this.queue = [];    // Ordered admin-scheduled queue entries: { itemId, trackId, addedAt }
    this.customPlaylist = []; // Custom playlist track IDs
    this.customPlaylistIndex = 0;
    this.shufflePool = [];
    this.lastPlayedId = null;
    this._recentlyDequeuedItemIds = []; // Tracks recently popped head IDs to tolerate reorder races

    this.queueFilePath = options.queueFilePath ||
      process.env.QUEUE_STATE_FILE ||
      path.join(__dirname, 'data', 'admin-queue.json');

    this._loadPersistedQueue();

    // Refresh pool and next track preview if music folder updates
    this.library.on('scanned', () => {
      this._onLibraryUpdated();
    });
  }

  /**
   * Initializes playback and selects the initial and next tracks without interrupting active listeners
   */
  start() {
    const tracks = this.library.getAllTracks();
    if (tracks.length === 0) {
      console.warn('[Scheduler] Warning: Starting scheduler with empty music library.');
      this.currentTrack = null;
      this.nextTrack = null;
      this.currentTrackSource = 'fallback_shuffle';
      this.nextTrackSource = 'fallback_shuffle';
      this.startTime = Date.now();
      return;
    }

    this._refillShufflePool();
    const picked = this._pickNextWithSource();
    this.currentTrack = picked.track;
    this.currentTrackSource = picked.source;
    this.startTime = Date.now();
    this.lastPlayedId = this.currentTrack ? this.currentTrack.id : null;
    this._refreshNextTrack();

    if (this.currentTrack) {
      console.log(`[Scheduler] Initial track [${this.currentTrackSource}]: "${this.currentTrack.title}" by ${this.currentTrack.artist} (${this.currentTrack.durationFormatted})`);
    }
    if (this.nextTrack) {
      console.log(`[Scheduler] Next up [${this.nextTrackSource}]: "${this.nextTrack.title}" by ${this.nextTrack.artist} (${this.nextTrack.durationFormatted})`);
    }

    this.emit('trackChange', {
      currentTrack: this.currentTrack,
      currentTrackSource: this.currentTrackSource,
      startTime: this.startTime,
      nextTrack: this.nextTrack,
      nextTrackSource: this.nextTrackSource,
      playbackMode: this.getPlaybackMode()
    });
  }

  /**
   * Advances the playback timeline cleanly to the next scheduled or fallback song
   */
  advance() {
    if (this.currentTrack) {
      this.history.unshift({
        ...this.currentTrack,
        source: this.currentTrackSource,
        playedAt: this.startTime
      });
      if (this.history.length > 20) this.history.pop();
    }

    const picked = this._pickNextWithSource();
    this.currentTrack = picked.track;
    this.currentTrackSource = picked.source;
    this.startTime = Date.now();
    this.lastPlayedId = this.currentTrack ? this.currentTrack.id : null;
    this._refreshNextTrack();

    if (this.currentTrack) {
      console.log(`[Scheduler] Advanced [${this.currentTrackSource}]: "${this.currentTrack.title}" by ${this.currentTrack.artist} (${this.currentTrack.durationFormatted})`);
    }
    if (this.nextTrack) {
      console.log(`[Scheduler] Next up [${this.nextTrackSource}]: "${this.nextTrack.title}" by ${this.nextTrack.artist} (${this.nextTrack.durationFormatted})`);
    }

    this.emit('trackChange', {
      currentTrack: this.currentTrack,
      currentTrackSource: this.currentTrackSource,
      startTime: this.startTime,
      nextTrack: this.nextTrack,
      nextTrackSource: this.nextTrackSource,
      playbackMode: this.getPlaybackMode()
    });

    return this.currentTrack;
  }

  /**
   * Validates that a track is indexed and its local MP3 file exists on disk
   */
  _isTrackAvailable(track) {
    if (!track) return false;
    if (typeof track.filePath === 'string' && track.filePath.length > 0) {
      return fs.existsSync(track.filePath);
    }
    return true;
  }

  _resolveValidTrack(trackId) {
    if (typeof trackId !== 'string' || trackId.trim().length === 0) return null;
    const track = this.library.getTrack(trackId);
    return this._isTrackAvailable(track) ? track : null;
  }

  _hasValidQueuedTrack() {
    return this.queue.some(entry => Boolean(this._resolveValidTrack(entry.trackId)));
  }

  /**
   * Returns 'admin_schedule' while an admin-scheduled track is active or pending in queue,
   * otherwise 'fallback' (automatic shuffled local folder rotation).
   */
  getPlaybackMode() {
    if (this.currentTrackSource === 'admin_schedule' || this._hasValidQueuedTrack()) {
      return 'admin_schedule';
    }
    return 'fallback';
  }

  getPlaybackModeLabel() {
    return this.getPlaybackMode() === 'admin_schedule'
      ? 'Up Next Queue'
      : 'Shuffle Fallback';
  }

  /**
   * Selects the next track according to strict priority:
   * 1. Admin-controlled schedule queue (skipping unavailable entries gracefully)
   * 2. Custom playlist mode (if configured)
   * 3. Automatic shuffle fallback across local music library
   */
  _pickNextWithSource() {
    // 1. Priority: Admin-controlled schedule queue
    let queueModified = false;
    while (this.queue.length > 0) {
      const entry = this.queue.shift();
      queueModified = true;
      if (entry && entry.itemId) {
        this._recordDequeuedItemId(entry.itemId);
      }

      const track = this._resolveValidTrack(entry && entry.trackId);
      if (track) {
        this._savePersistedQueue();
        return { track, source: 'admin_schedule' };
      }

      console.warn(`[Scheduler] Skipping unavailable scheduled track: ${entry ? entry.trackId : 'unknown'}`);
    }
    if (queueModified) {
      this._savePersistedQueue();
    }

    // 2. Legacy custom playlist mode
    if (this.mode === 'playlist' && this.customPlaylist.length > 0) {
      const len = this.customPlaylist.length;
      for (let attempts = 0; attempts < len; attempts++) {
        const trackId = this.customPlaylist[this.customPlaylistIndex % len];
        this.customPlaylistIndex++;
        const track = this._resolveValidTrack(trackId);
        if (track) {
          return { track, source: 'custom_playlist' };
        }
      }
    }

    // 3. Automatic Fallback: endless shuffle with back-to-back repeat guard
    const allTracks = this.library.getAllTracks().filter(t => this._isTrackAvailable(t));
    if (allTracks.length === 0) return { track: null, source: 'fallback_shuffle' };
    if (allTracks.length === 1) return { track: allTracks[0], source: 'fallback_shuffle' };

    if (this.shufflePool.length === 0) {
      this._refillShufflePool();
    }

    // Drop any stale pool items that vanished since last scan
    while (this.shufflePool.length > 0 && !this._isTrackAvailable(this.shufflePool[0])) {
      this.shufflePool.shift();
    }
    if (this.shufflePool.length === 0) {
      this._refillShufflePool();
    }

    // Prevent back-to-back identical song when starting a refreshed pool
    if (this.shufflePool.length > 1 && this.shufflePool[0].id === this.lastPlayedId) {
      const swapIdx = 1 + Math.floor(Math.random() * (this.shufflePool.length - 1));
      const temp = this.shufflePool[0];
      this.shufflePool[0] = this.shufflePool[swapIdx];
      this.shufflePool[swapIdx] = temp;
    }

    const picked = this.shufflePool.shift() || allTracks[0];
    return { track: picked, source: 'fallback_shuffle' };
  }

  _pickNext() {
    return this._pickNextWithSource().track;
  }

  /**
   * Peeks at the next eligible track without modifying queue state
   */
  _peekNextWithSource() {
    for (const entry of this.queue) {
      const track = this._resolveValidTrack(entry.trackId);
      if (track) {
        return { track, source: 'admin_schedule' };
      }
    }

    if (this.mode === 'playlist' && this.customPlaylist.length > 0) {
      const len = this.customPlaylist.length;
      for (let offset = 0; offset < len; offset++) {
        const trackId = this.customPlaylist[(this.customPlaylistIndex + offset) % len];
        const track = this._resolveValidTrack(trackId);
        if (track) {
          return { track, source: 'custom_playlist' };
        }
      }
    }

    for (const candidate of this.shufflePool) {
      if (this._isTrackAvailable(candidate) && candidate.id !== (this.currentTrack && this.currentTrack.id)) {
        return { track: candidate, source: 'fallback_shuffle' };
      }
    }

    const all = this.library.getAllTracks().filter(t => this._isTrackAvailable(t));
    if (all.length > 1) {
      const currentId = this.currentTrack ? this.currentTrack.id : this.lastPlayedId;
      const candidate = all.find(t => t.id !== currentId);
      return { track: candidate || all[0], source: 'fallback_shuffle' };
    }
    return { track: all[0] || null, source: 'fallback_shuffle' };
  }

  _peekNext() {
    return this._peekNextWithSource().track;
  }

  _refreshNextTrack() {
    const upcoming = this._peekNextWithSource();
    this.nextTrack = upcoming.track;
    this.nextTrackSource = upcoming.source;
  }

  _refillShufflePool() {
    const all = this.library.getAllTracks().filter(t => this._isTrackAvailable(t));
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
      this._refreshNextTrack();
    }
  }

  _recordDequeuedItemId(itemId) {
    this._recentlyDequeuedItemIds.push(itemId);
    if (this._recentlyDequeuedItemIds.length > 25) {
      this._recentlyDequeuedItemIds.shift();
    }
  }

  _loadPersistedQueue() {
    try {
      if (!this.queueFilePath || !fs.existsSync(this.queueFilePath)) {
        return;
      }
      const raw = fs.readFileSync(this.queueFilePath, 'utf8');
      if (!raw || !raw.trim()) return;

      const parsed = JSON.parse(raw);
      const items = Array.isArray(parsed) ? parsed : (Array.isArray(parsed.queue) ? parsed.queue : []);

      const sanitized = [];
      for (const entry of items) {
        if (!entry || typeof entry.trackId !== 'string' || !entry.trackId.trim()) continue;
        sanitized.push({
          itemId: (typeof entry.itemId === 'string' && entry.itemId.trim())
            ? entry.itemId.trim()
            : crypto.randomUUID(),
          trackId: entry.trackId.trim(),
          addedAt: (typeof entry.addedAt === 'string' && entry.addedAt)
            ? entry.addedAt
            : new Date().toISOString()
        });
      }

      this.queue = sanitized;
      if (sanitized.length > 0) {
        console.log(`[Scheduler] Restored ${sanitized.length} persisted scheduled song(s) from disk.`);
      }
    } catch (err) {
      console.warn('[Scheduler] Warning: Could not load persisted admin queue:', err.message);
    }
  }

  _savePersistedQueue() {
    if (!this.queueFilePath) return;
    try {
      const dir = path.dirname(this.queueFilePath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      const tmpPath = `${this.queueFilePath}.tmp`;
      const payload = JSON.stringify({
        version: 1,
        updatedAt: new Date().toISOString(),
        queue: this.queue
      }, null, 2);
      fs.writeFileSync(tmpPath, payload, 'utf8');
      fs.renameSync(tmpPath, this.queueFilePath);
    } catch (err) {
      console.error('[Scheduler] Failed to persist admin queue:', err.message);
    }
  }

  /**
   * Adds one track to the admin-controlled queue without interrupting current playback
   */
  enqueueAdminTrack(trackId, options = {}) {
    if (typeof trackId !== 'string' || !trackId.trim()) {
      return { ok: false, status: 400, error: 'trackId must be a non-empty string' };
    }
    const cleanId = trackId.trim();
    const track = this._resolveValidTrack(cleanId);
    if (!track) {
      return { ok: false, status: 404, error: `Track "${cleanId}" was not found or is unavailable in the local library` };
    }

    const entry = {
      itemId: crypto.randomUUID(),
      trackId: cleanId,
      addedAt: new Date().toISOString()
    };

    if (options.position !== undefined && options.position !== null) {
      if (!Number.isInteger(options.position) || options.position < 0 || options.position > this.queue.length) {
        return { ok: false, status: 400, error: `position must be an integer between 0 and ${this.queue.length}` };
      }
      this.queue.splice(options.position, 0, entry);
    } else {
      this.queue.push(entry);
    }

    this._savePersistedQueue();
    this._refreshNextTrack();
    this.emit('queueChange', this.getAdminQueueState());

    console.log(`[Scheduler] Enqueued admin track: "${track.title}" by ${track.artist} (queue length: ${this.queue.length})`);
    return { ok: true, item: this._formatQueueEntry(entry, this.queue.indexOf(entry)) };
  }

  /**
   * Adds multiple tracks sequentially to the admin queue without interrupting current playback
   */
  enqueueAdminTracks(trackIds) {
    if (!Array.isArray(trackIds) || trackIds.length === 0) {
      return { ok: false, status: 400, error: 'trackIds must be a non-empty array' };
    }
    if (trackIds.length > 250) {
      return { ok: false, status: 400, error: 'Cannot add more than 250 tracks in a single request' };
    }

    const validTracks = [];
    for (const rawId of trackIds) {
      if (typeof rawId !== 'string' || !rawId.trim()) {
        return { ok: false, status: 400, error: 'All trackIds must be non-empty strings' };
      }
      const cleanId = rawId.trim();
      const track = this._resolveValidTrack(cleanId);
      if (!track) {
        return { ok: false, status: 404, error: `Track "${cleanId}" was not found or is unavailable` };
      }
      validTracks.push({ trackId: cleanId, track });
    }

    const nowIso = new Date().toISOString();
    const inserted = [];
    for (const { trackId } of validTracks) {
      const entry = {
        itemId: crypto.randomUUID(),
        trackId,
        addedAt: nowIso
      };
      this.queue.push(entry);
      inserted.push(entry);
    }

    this._savePersistedQueue();
    this._refreshNextTrack();
    this.emit('queueChange', this.getAdminQueueState());

    return {
      ok: true,
      items: inserted.map(entry => this._formatQueueEntry(entry, this.queue.indexOf(entry)))
    };
  }

  /**
   * Reorders pending scheduled tracks by full itemId order or single-item index move,
   * never interrupting the currently playing track.
   */
  reorderQueue({ orderedItemIds, itemId, newIndex } = {}) {
    if (Array.isArray(orderedItemIds)) {
      const seen = new Set();
      for (const id of orderedItemIds) {
        if (typeof id !== 'string' || !id.trim()) {
          return { ok: false, status: 400, error: 'orderedItemIds must contain non-empty strings' };
        }
        if (seen.has(id)) {
          return { ok: false, status: 400, error: `Duplicate itemId "${id}" in orderedItemIds` };
        }
        seen.add(id);
      }

      const byId = new Map(this.queue.map(entry => [entry.itemId, entry]));
      const recentSet = new Set(this._recentlyDequeuedItemIds);
      const reordered = [];

      for (const id of orderedItemIds) {
        if (byId.has(id)) {
          reordered.push(byId.get(id));
          byId.delete(id);
        } else if (!recentSet.has(id)) {
          return { ok: false, status: 400, error: `Unknown queue itemId "${id}"` };
        }
      }

      // Preserve any items appended concurrently in the background at the end
      for (const remaining of this.queue) {
        if (byId.has(remaining.itemId)) {
          reordered.push(remaining);
        }
      }

      this.queue = reordered;
      this._savePersistedQueue();
      this._refreshNextTrack();
      this.emit('queueChange', this.getAdminQueueState());
      return { ok: true };
    }

    if (typeof itemId === 'string' && itemId.trim() && Number.isInteger(newIndex)) {
      const cleanId = itemId.trim();
      const fromIndex = this.queue.findIndex(entry => entry.itemId === cleanId);
      if (fromIndex === -1) {
        return { ok: false, status: 404, error: `Queue item "${cleanId}" not found` };
      }
      if (newIndex < 0 || newIndex >= this.queue.length) {
        return { ok: false, status: 400, error: `newIndex must be between 0 and ${Math.max(0, this.queue.length - 1)}` };
      }

      const [moved] = this.queue.splice(fromIndex, 1);
      this.queue.splice(newIndex, 0, moved);

      this._savePersistedQueue();
      this._refreshNextTrack();
      this.emit('queueChange', this.getAdminQueueState());
      return { ok: true };
    }

    return { ok: false, status: 400, error: 'Provide either orderedItemIds array or itemId with integer newIndex' };
  }

  /**
   * Removes a pending song from the admin queue by queue itemId without affecting current track
   */
  removeQueueItem(itemId) {
    if (typeof itemId !== 'string' || !itemId.trim()) {
      return { ok: false, status: 400, error: 'itemId must be a non-empty string' };
    }
    const cleanId = itemId.trim();
    const idx = this.queue.findIndex(entry => entry.itemId === cleanId);
    if (idx === -1) {
      return { ok: false, status: 404, error: `Queue item "${cleanId}" not found` };
    }

    const [removed] = this.queue.splice(idx, 1);
    this._savePersistedQueue();
    this._refreshNextTrack();
    this.emit('queueChange', this.getAdminQueueState());

    return { ok: true, removed };
  }

  /**
   * Clears all pending admin-scheduled songs without interrupting the currently playing song
   */
  clearQueue() {
    const clearedCount = this.queue.length;
    this.queue = [];
    this._savePersistedQueue();
    this._refreshNextTrack();
    this.emit('queueChange', this.getAdminQueueState());
    return { ok: true, clearedCount };
  }

  /**
   * Legacy helper: Enqueues a specific track to play next
   */
  enqueueTrack(trackId) {
    return this.enqueueAdminTrack(trackId).ok;
  }

  /**
   * Sets custom playlist ordering
   */
  setPlaylist(trackIds) {
    this.customPlaylist = trackIds.filter(id => Boolean(this.library.getTrack(id)));
    this.customPlaylistIndex = 0;
    this.mode = 'playlist';
    this._refreshNextTrack();
    console.log(`[Scheduler] Set custom playlist with ${this.customPlaylist.length} track(s).`);
  }

  setMode(mode) {
    if (mode === 'shuffle' || mode === 'playlist') {
      this.mode = mode;
      this._refreshNextTrack();
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

  _formatQueueEntry(entry, index) {
    const track = this.library.getTrack(entry.trackId);
    const available = Boolean(track && this._isTrackAvailable(track));
    return {
      itemId: entry.itemId,
      trackId: entry.trackId,
      position: index + 1,
      title: track ? track.title : entry.trackId,
      artist: track ? track.artist : 'Unavailable track',
      album: track ? track.album : 'PulseCast Music Library',
      durationSeconds: track ? track.durationSeconds : 0,
      durationFormatted: track ? track.durationFormatted : '00:00',
      available,
      addedAt: entry.addedAt
    };
  }

  /**
   * Full state returned to authenticated admin scheduling tools
   */
  getAdminQueueState() {
    const timeline = this.getTimeline();
    const formattedQueue = this.queue.map((entry, idx) => this._formatQueueEntry(entry, idx));
    const libraryTracks = this.library.getAllTracks().map(t => ({
      id: t.id,
      title: t.title,
      artist: t.artist,
      album: t.album,
      durationSeconds: t.durationSeconds,
      durationFormatted: t.durationFormatted,
      bitrateKbps: t.bitrateKbps,
      fileSize: t.fileSize
    }));

    return {
      success: true,
      channel: 6,
      stationName: 'PulseCast Radio',
      playbackMode: timeline.playbackMode,
      playbackModeLabel: timeline.playbackModeLabel,
      currentTrackSource: timeline.currentTrackSource,
      isScheduleQueuedNext: timeline.isScheduleQueuedNext,
      currentTrack: timeline.currentTrack,
      elapsedSeconds: timeline.elapsedSeconds,
      remainingSeconds: timeline.remainingSeconds,
      nextTrack: timeline.nextTrack,
      queueCount: formattedQueue.length,
      queue: formattedQueue,
      libraryCount: libraryTracks.length,
      library: libraryTracks
    };
  }

  getTimeline() {
    const elapsed = this.getElapsedSeconds();
    const duration = this.currentTrack ? this.currentTrack.durationSeconds : 0;
    const remaining = Math.max(0, duration - elapsed);
    const playbackMode = this.getPlaybackMode();
    const playbackModeLabel = this.getPlaybackModeLabel();
    const isScheduleQueuedNext = this.currentTrackSource !== 'admin_schedule' && this._hasValidQueuedTrack();

    return {
      currentTrack: this.currentTrack ? {
        id: this.currentTrack.id,
        title: this.currentTrack.title,
        artist: this.currentTrack.artist,
        album: this.currentTrack.album,
        durationSeconds: this.currentTrack.durationSeconds,
        durationFormatted: this.currentTrack.durationFormatted,
        bitrateKbps: this.currentTrack.bitrateKbps,
        sampleRateHz: this.currentTrack.sampleRateHz,
        source: this.currentTrackSource
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
        durationFormatted: this.nextTrack.durationFormatted,
        source: this.nextTrackSource
      } : null,
      mode: this.mode,
      playbackMode,
      playbackModeLabel,
      currentTrackSource: this.currentTrackSource,
      isScheduleQueuedNext,
      queueCount: this.queue.length,
      pendingQueueCount: this.queue.length,
      history: this.history.slice(0, 5).map(h => ({
        title: h.title,
        artist: h.artist,
        source: h.source || 'fallback_shuffle',
        playedAt: new Date(h.playedAt).toISOString()
      }))
    };
  }
}

module.exports = Scheduler;
