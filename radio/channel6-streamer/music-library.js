const fs = require('fs');
const path = require('path');
const EventEmitter = require('events');

/**
 * MusicLibrary scans, parses and indexes audio tracks from the Channel 6 music folder.
 * Extracts accurate metadata, frame counts, bitrates and audio byte boundaries without external binaries.
 */
class MusicLibrary extends EventEmitter {
  constructor(options = {}) {
    super();
    this.musicDir = options.musicDir || process.env.MUSIC_DIR || this._resolveDefaultMusicDir();
    this.tracks = new Map(); // id -> track
    this.trackList = [];     // Array of tracks
    this.watcher = null;
    this._scanDebounceTimer = null;
  }

  /**
   * Resolves the primary music folder location across local environments
   */
  _resolveDefaultMusicDir() {
    const candidates = [
      'C:\\pulsecast-radio\\music',
      path.resolve(__dirname, '..', 'music'),
      path.resolve(__dirname, '..', '..', 'music'),
      path.resolve(__dirname, 'music')
    ];
    for (const dir of candidates) {
      if (fs.existsSync(dir)) {
        return dir;
      }
    }
    return candidates[0]; // fallback
  }

  /**
   * Scans the music directory and indexes all MP3 files
   */
  async scan() {
    if (!fs.existsSync(this.musicDir)) {
      console.warn(`[MusicLibrary] Warning: Music directory does not exist: ${this.musicDir}`);
      this.tracks.clear();
      this.trackList = [];
      return this.trackList;
    }

    const files = fs.readdirSync(this.musicDir).filter(f => f.toLowerCase().endsWith('.mp3'));
    console.log(`[MusicLibrary] Scanning ${files.length} audio file(s) in: ${this.musicDir}`);

    const newTracks = new Map();
    const newTrackList = [];

    for (const file of files) {
      const filePath = path.join(this.musicDir, file);
      try {
        const track = await this._parseMp3File(filePath);
        if (track) {
          newTracks.set(track.id, track);
          newTrackList.push(track);
        }
      } catch (err) {
        console.error(`[MusicLibrary] Failed to parse file "${file}":`, err.message);
      }
    }

    this.tracks = newTracks;
    this.trackList = newTrackList;
    console.log(`[MusicLibrary] Successfully indexed ${this.trackList.length} track(s).`);
    this.emit('scanned', this.trackList);
    return this.trackList;
  }

  /**
   * Parses an MP3 file to extract ID3 tags, MPEG frame details, exact duration, and audio byte offset
   */
  async _parseMp3File(filePath) {
    const stat = fs.statSync(filePath);
    const fileSize = stat.size;
    if (fileSize < 1024) return null; // Ignore tiny/corrupt files

    const fd = fs.openSync(filePath, 'r');
    try {
      // 1. Read first 64KB for ID3v2 header and tags
      const headerBufSize = Math.min(65536, fileSize);
      const headerBuf = Buffer.alloc(headerBufSize);
      fs.readSync(fd, headerBuf, 0, headerBufSize, 0);

      let audioStart = 0;
      let title = null;
      let artist = null;
      let album = null;

      if (headerBuf.subarray(0, 3).toString('ascii') === 'ID3') {
        const id3Size = ((headerBuf[6] & 0x7f) << 21) |
                        ((headerBuf[7] & 0x7f) << 14) |
                        ((headerBuf[8] & 0x7f) << 7)  |
                        (headerBuf[9] & 0x7f);
        audioStart = 10 + id3Size;

        // Parse ID3v2 tags (TIT2, TPE1, TALB)
        let pos = 10;
        const tagEnd = Math.min(headerBufSize, audioStart);
        while (pos < tagEnd - 10) {
          const fid = headerBuf.subarray(pos, pos + 4).toString('ascii');
          if (!/^[A-Z0-9]{4}$/.test(fid)) break;
          const fsize = headerBuf.readUInt32BE(pos + 4);
          if (fsize <= 0 || pos + 10 + fsize > tagEnd) break;

          const fcontent = headerBuf.subarray(pos + 10, pos + 10 + fsize);
          const enc = fcontent[0];
          const raw = fcontent.subarray(1);
          let val = '';
          if (enc === 0) val = raw.toString('latin1');
          else if (enc === 1) val = raw.toString('utf16le');
          else if (enc === 3) val = raw.toString('utf8');
          else val = raw.toString('utf8');
          val = val.replace(/\0/g, '').trim();

          if (fid === 'TIT2' && val) title = val;
          if (fid === 'TPE1' && val) artist = val;
          if (fid === 'TALB' && val) album = val;

          pos += 10 + fsize;
        }
      }

      // Fallback: parse clean artist & title from filename
      const parsedFn = this._parseFilename(path.basename(filePath));
      if (!title) title = parsedFn.title;
      if (!artist) artist = parsedFn.artist;
      if (!album) album = 'PulseCast Music Library';

      // 2. Scan audio frames to compute exact duration & audio byte length
      const brMap = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0];
      const srMap = [44100, 48000, 32000, 0];

      // Read audio data in chunks to find frames and calculate duration
      // For accurate frame counting without high memory usage, we can scan sequentially
      let firstSyncOffset = -1;
      let sampleRate = 44100;
      let totalFrames = 0;
      let totalBitrateSum = 0;
      let lastValidOffset = audioStart;

      // Read buffer for frame scanning
      const scanChunkSize = 256 * 1024; // 256 KB buffer
      const scanBuf = Buffer.alloc(scanChunkSize);
      let filePos = audioStart;

      while (filePos < fileSize) {
        const bytesRead = fs.readSync(fd, scanBuf, 0, Math.min(scanChunkSize, fileSize - filePos), filePos);
        if (bytesRead < 4) break;

        let bufOffset = 0;
        while (bufOffset < bytesRead - 4) {
          if (scanBuf[bufOffset] === 0xFF && (scanBuf[bufOffset + 1] & 0xE0) === 0xE0) {
            const b1 = scanBuf[bufOffset + 1];
            const b2 = scanBuf[bufOffset + 2];
            const ver = (b1 >> 3) & 0x03;
            const layer = (b1 >> 1) & 0x03;
            const brIdx = (b2 >> 4) & 0x0F;
            const srIdx = (b2 >> 2) & 0x03;
            const pad = (b2 >> 1) & 0x01;

            if (ver === 3 && layer === 1 && brIdx > 0 && brIdx < 15 && srIdx < 3) {
              const br = brMap[brIdx];
              const sr = srMap[srIdx];
              const frameLen = Math.floor((144 * br * 1000) / sr) + pad;

              if (firstSyncOffset === -1) {
                firstSyncOffset = filePos + bufOffset;
                sampleRate = sr;
              }

              totalFrames++;
              totalBitrateSum += br;
              lastValidOffset = filePos + bufOffset + frameLen;
              bufOffset += frameLen;
              continue;
            }
          }
          bufOffset++;
        }

        // Advance by bufOffset
        filePos += bufOffset;
      }

      if (firstSyncOffset === -1) {
        firstSyncOffset = audioStart;
      }

      const audioBytes = Math.max(0, lastValidOffset - firstSyncOffset);
      const avgBitrateKbps = totalFrames > 0 ? Math.round(totalBitrateSum / totalFrames) : 192;
      const durationSeconds = totalFrames > 0 ? (totalFrames * 1152) / sampleRate : (audioBytes * 8) / (avgBitrateKbps * 1000);
      const byteRate = durationSeconds > 0 ? audioBytes / durationSeconds : (avgBitrateKbps * 1000) / 8;

      const trackId = path.basename(filePath).toLowerCase().replace(/[^a-z0-9_-]/g, '_');

      return {
        id: trackId,
        filename: path.basename(filePath),
        filePath: filePath,
        fileSize: fileSize,
        title: title,
        artist: artist,
        album: album,
        audioStart: firstSyncOffset,
        audioEnd: lastValidOffset,
        audioBytes: audioBytes,
        sampleRate: sampleRate,
        bitrateKbps: avgBitrateKbps,
        totalFrames: totalFrames,
        durationSeconds: durationSeconds,
        durationFormatted: this._formatDuration(durationSeconds),
        byteRate: byteRate
      };
    } finally {
      fs.closeSync(fd);
    }
  }

  /**
   * Helper to clean and parse title & artist from filename
   */
  _parseFilename(filename) {
    let base = path.parse(filename).name;
    base = base
      .replace(/\s*\(Lyrics\)\s*/i, '')
      .replace(/\s*\[Lyrics\]\s*/i, '')
      .replace(/\s*\(Official Video\)\s*/i, '')
      .replace(/\s*\(Audio\)\s*/i, '')
      .trim();

    const parts = base.split(' - ');
    if (parts.length >= 2) {
      return {
        artist: parts[0].trim(),
        title: parts.slice(1).join(' - ').trim()
      };
    }
    return {
      artist: 'PulseCast Artist',
      title: base
    };
  }

  _formatDuration(seconds) {
    const totalSec = Math.round(seconds);
    const mins = Math.floor(totalSec / 60);
    const secs = totalSec % 60;
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }

  /**
   * Starts directory watcher to detect file additions or removals
   */
  startWatching() {
    if (this.watcher || !fs.existsSync(this.musicDir)) return;
    try {
      this.watcher = fs.watch(this.musicDir, (eventType, filename) => {
        if (!filename || !filename.toLowerCase().endsWith('.mp3')) return;
        clearTimeout(this._scanDebounceTimer);
        this._scanDebounceTimer = setTimeout(() => {
          console.log(`[MusicLibrary] Detected change in music folder (${eventType}: ${filename}), rescanning...`);
          this.scan();
        }, 1000);
      });
      console.log(`[MusicLibrary] Watching for changes in: ${this.musicDir}`);
    } catch (err) {
      console.warn(`[MusicLibrary] Directory watcher could not be started:`, err.message);
    }
  }

  stopWatching() {
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }
    clearTimeout(this._scanDebounceTimer);
  }

  getAllTracks() {
    return [...this.trackList];
  }

  getTrack(id) {
    return this.tracks.get(id);
  }

  getTrackCount() {
    return this.trackList.length;
  }
}

module.exports = MusicLibrary;

