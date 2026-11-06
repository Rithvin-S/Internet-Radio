# PulseCast — Channel 6: Independent 24/7 Automated Radio Station
## Comprehensive Inspection & Implementation Plan (Stage A)

**Date**: November 6, 2026  
**Status**: Stage A — Architecture Inspection Complete (Awaiting User Approval for Stage B)  
**Author**: Antigravity Pair Programmer  

---

## 1. Executive Summary

PulseCast currently operates two primary station archetypes:
1. **Curated Web Streams (Stations 1–5)**: External third-party Icecast/HLS streams (Radio Paradise, Nightwave Plaza, KEXP, SomaFM).
2. **AWS Scheduled Broadcast (Station 7)**: An internal broadcast pipeline hosted on an AWS EC2 instance, driven by calendar-based program schedules, playing audio tracks from a private Supabase Storage bucket (`pulsecast-music-library`) via Liquidsoap and Icecast.

**Channel 6 (Station ID: 6)** is currently configured as a local development placeholder pointing to `http://localhost:8000/pulsecast.mp3`.

### The Channel 6 Mission
Transform Channel 6 into a **publicly accessible, continuously running (24/7), automated internet radio station** that:
- Draws audio exclusively from the existing Supabase Storage music library.
- Shuffles songs indefinitely in random order with immediate consecutive-repeat prevention.
- Automatically incorporates newly added songs without restarting Liquidsoap, Icecast, or EC2.
- Handles empty collections gracefully with continuous silence frames (zero dead air, no crashes).
- Streams publicly over HTTPS at `https://pulsecast.duckdns.org/channel6.mp3`.
- Allows full collection and status management via the PulseCast Admin Portal (Web & Flutter).
- **Protects Channel 7 and all existing production infrastructure with 100% isolation**.

---

## 2. Existing Production Architecture Inspection

### 2.1 Station 6 Current Implementation
- **Database Entry (`public.stations`)**:
  ```json
  {
    "id": 6,
    "name": "PulseCast Radio",
    "description": "Automated radio with random music playback",
    "genre": "Mixed",
    "stream_url": "http://localhost:8000/pulsecast.mp3",
    "is_active": true
  }
  ```
- **Backend Dispatcher State**:
  Calling `streamingService.resolveStationNextTrack(6)` executes a query against `public.program_schedules` for `station_id = 6`. Because no calendar schedules exist for station 6, it returns:
  ```json
  {
    "success": true,
    "has_schedule": false,
    "fallback": true,
    "station_id": 6,
    "station_name": "PulseCast Radio",
    "message": "No active schedule"
  }
  ```
- **Playback Infrastructure**:
  There is currently no running daemon, no dedicated mountpoint, and no remote streaming pipeline for Station 6. The `http://localhost:8000/pulsecast.mp3` URL is an artifact of local developer test scripts (`icecast_local_start.bat`).

### 2.2 Station 7 Current Implementation (Production AWS)
- **Database Entry (`public.stations`)**:
  ```json
  {
    "id": 7,
    "name": "PulseCast Radio (AWS)",
    "description": "Automated radio with random music playback",
    "genre": "Mixed",
    "stream_url": "https://pulsecast.duckdns.org/pulsecast.mp3",
    "is_active": true
  }
  ```
- **Operational Model**:
  Station 7 is strictly **schedule-driven**.
  1. An admin creates a schedule in Google Calendar format (`schedule_date`, `start_time`, `end_time` in Asia/Kolkata timezone).
  2. Tracks are attached to the schedule via `schedule_tracks` in fixed `play_order`.
  3. When the schedule is active, `resolveStationNextTrack(7)` serves tracks sequentially and advances the cursor.
  4. When no schedule is active, the dispatcher returns `has_schedule: false`, and the station broadcasts silence.
- **EC2 Infrastructure**:
  - **Host**: AWS EC2 Ubuntu instance at `/opt/pulsecast-radio/`.
  - **Docker Compose Services**:
    - `pulsecast-icecast`: Infiniteproject Icecast container exposing port 8000.
    - `pulsecast-liquidsoap`: Savonet Liquidsoap v2.3.3 running `radio.liq`. Mounts Icecast at `/pulsecast.mp3`. Exposes telnet interface strictly on `127.0.0.1:1234`.
  - **Sync Daemon (`pulsecast_sync_daemon.py`)**:
    - Runs as a systemd host service.
    - Authenticates to Render backend via `x-radio-token` (`RADIO_STREAMING_KEY`).
    - Polls `GET /api/streaming/stations/7/next-track`.
    - Downloads Supabase signed URLs to `/opt/pulsecast-radio/cache`.
    - Validates MP3 sync frames and SHA-256 hash.
    - Enqueues container paths `/cache/<id>.mp3` into `supabase_queue` via Liquidsoap telnet.
    - Signals `?advance=true` only after successful enqueue.
    - Evicts finished files using an LRU cache limiter (500 MB max).
  - **Public Routing**:
    - Caddy on EC2 handles automated Let's Encrypt TLS for `pulsecast.duckdns.org` and proxies `/pulsecast.mp3` to `http://127.0.0.1:8000/pulsecast.mp3`.

### 2.3 Supabase Audio Retrieval & Storage Pipeline
- **Storage Bucket**: `pulsecast-music-library` (Private).
- **Metadata Table**: `public.songs`:
  - `id`: UUID (Primary Key)
  - `title`, `artist`, `album`, `duration`, `duration_seconds`
  - `mime_type`, `file_size_bytes`, `file_hash` (SHA-256 for duplicate detection)
  - `storage_bucket`: `"pulsecast-music-library"`
  - `storage_path`: `"library/<song-uuid>/<sanitized-filename>.mp3"`
  - `is_active`: Boolean (supports soft archival)
- **Security & Signed URLs**:
  - The bucket is **never public**.
  - Ephemeral signed URLs (300 seconds / 5 minutes) are generated just-in-time by the backend using `SUPABASE_SECRET_KEY`:
    `supabase.storage.from('pulsecast-music-library').createSignedUrl(storage_path, 300)`.
  - The Python daemon downloads the complete audio file into its local cache before pushing the path to Liquidsoap. Short-lived signed URLs are **never** passed into Liquidsoap's long-lived playback queues.

### 2.4 Playlist & Catalogue Schema Assessment
- `public.upcoming_tracks`: Legacy integer-based tracks for stations 1–5 (`General Library`).
- `public.schedule_tracks`: Maps UUID songs to specific time-slotted `program_schedules` (Station 7).
- **Identified Architectural Gap**:
  There is currently **no table or schema mechanism** for associating a collection of Supabase songs with a station for continuous 24/7 automated shuffle playback without calendar dates and time slots.

---

## 3. Proposed Isolated Channel 6 Architecture

To fulfill all requirements while keeping Channel 7 and production 100% stable, we propose the following isolated architecture:

```
               [ Supabase Storage ] (pulsecast-music-library)
                         |
                         | (Just-in-Time 5-min Signed URL via backend)
                         v
              [ Channel 6 Sync Daemon ] (pulsecast_ch6_daemon.py)
              - Polls Station 6 Dispatcher
              - Random selection with no immediate repeats
              - Validates MP3 & SHA-256
              - Downloads to /cache_ch6
                         |
                         | Telnet (Port 1235)
                         v
          [ Channel 6 Liquidsoap Engine ] (pulsecast-liquidsoap-ch6)
          - Queue: ch6_queue
          - Fallback: fallback([ch6_queue, blank()])
          - Mounts to Icecast /channel6.mp3
                         |
                         v
             [ Shared Icecast Server ] (pulsecast-icecast:8000)
             - Mount 1: /pulsecast.mp3  (Station 7 - Untouched)
             - Mount 2: /channel6.mp3   (Station 6 - Isolated)
                         |
                         v
            [ Caddy Reverse Proxy (HTTPS:443) ]
                         |
                         v
          https://pulsecast.duckdns.org/channel6.mp3
```

---

## 4. Key Architectural Decisions

### 4.1 Database Design: Dedicated `public.station_songs` Table
To avoid polluting calendar schedules or creating dummy 24-hour schedules, we propose the smallest, cleanly isolated database extension:

```sql
CREATE TABLE IF NOT EXISTS public.station_songs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id BIGINT NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
  song_id UUID NOT NULL REFERENCES public.songs(id) ON DELETE CASCADE,
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  added_by BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT uq_station_songs UNIQUE (station_id, song_id)
);

CREATE INDEX IF NOT EXISTS idx_station_songs_station ON public.station_songs (station_id);
CREATE INDEX IF NOT EXISTS idx_station_songs_song ON public.station_songs (song_id);

-- RLS & Permissions
ALTER TABLE public.station_songs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view station songs" ON public.station_songs FOR SELECT TO anon, authenticated USING (TRUE);
GRANT ALL ON TABLE public.station_songs TO service_role;
```

**Benefits**:
- Zero impact on existing tables (`songs`, `stations`, `program_schedules`, `schedule_tracks`).
- Station-agnostic: Station 6 has its own pool; future automated channels can reuse it.
- Deduplication: `UNIQUE (station_id, song_id)` guarantees a song cannot be added twice to the pool.
- Cascade safety: Deleting a song or station automatically cleans up association rows without orphaned records.

### 4.2 Random Playback Engine & Dispatcher
In `backend/src/services/streamingService.js`:
- Introduce a station-aware branching in `resolveStationNextTrack(stationId, options)`:
  - If `stationId === 6`:
    1. Query all active songs in `station_songs` for `station_id = 6`.
    2. If collection count is 0:
       Return `{ success: true, has_collection: false, total_songs: 0, message: "Channel 6 collection is empty" }`.
    3. If collection count $\ge 1$:
       - Retrieve recent playback history for Station 6 from in-memory state: `lastPlayedSongId`.
       - Filter candidate songs: if `total_songs >= 2`, exclude `lastPlayedSongId` so the same song **never plays twice consecutively**.
       - If `total_songs === 1`, allow the single song to repeat.
       - Select uniformly at random among candidates:
         `const nextSong = candidates[Math.floor(Math.random() * candidates.length)]`.
       - Update `lastPlayedSongId = nextSong.id`.
       - Generate an ephemeral 300s signed URL via `songService.generateSignedUrl(nextSong.id, 300)`.
       - Return track payload with `has_collection: true, is_signed_url: true`.
  - If `stationId === 7`:
    - Preserves existing calendar schedule resolution **100% unaltered**.

### 4.3 Instant Eligibility on New Song Addition (Zero Restart)
- Because the daemon polls the dispatcher before each track change (when $\le 25$s remaining), whenever an admin adds or removes a song in `station_songs`, the dispatcher immediately includes or excludes that song in the candidate pool for the **very next selection**.
- The currently streaming song is not interrupted.
- No Liquidsoap, Icecast, or server process restarts are required.

### 4.4 EC2 Infrastructure Isolation: Dedicated Liquidsoap Container & Daemon
To guarantee that Channel 7 is **never restarted, interrupted, or endangered**:
1. **Shared Icecast**:
   - Icecast dynamically accepts multiple source mounts on the fly.
   - Mount `/channel6.mp3` will be created dynamically when Channel 6's Liquidsoap connects.
   - Channel 7's mount (`/pulsecast.mp3`) experiences zero downtime.
2. **Channel 6 Liquidsoap (`radio_ch6.liq`)**:
   - Runs in a separate Docker container `pulsecast-liquidsoap-ch6`.
   - Telnet interface: `127.0.0.1:1235` (strictly isolated from Station 7's `1234`).
   - Cache directory: `./cache_ch6` (mounted read-only into `/cache`).
   - Fallback source: `fallback(track_sensitive=false, [ch6_queue, blank()])`.
   - Icecast output: `%mp3(bitrate=128)` to `mount="/channel6.mp3"`.
3. **Channel 6 Sync Daemon (`pulsecast_ch6_daemon.py`)**:
   - Configured with `RADIO_STATION_ID=6`, `LIQUIDSOAP_PORT=1235`, `CACHE_DIR=/opt/pulsecast-radio/cache_ch6`.
   - Atomic downloads to `.tmp_...` followed by rename to `<id>.mp3`.
   - Independent LRU cache management.
   - Handles empty collection by idling and sleeping with exponential backoff, leaving Liquidsoap streaming silence (`blank()`) until songs are added.

### 4.5 Public Streaming URL & Caddy Configuration
- Target Public Stream: `https://pulsecast.duckdns.org/channel6.mp3`
- Content-Type: `audio/mpeg`
- Caddy reverse-proxy on EC2 handles `/channel6.mp3` -> `http://127.0.0.1:8000/channel6.mp3` under the existing TLS certificate.
- Update `public.stations` database record for station ID 6:
  `stream_url = 'https://pulsecast.duckdns.org/channel6.mp3'`.

### 4.6 Admin Portal Management Endpoints
Add dedicated administrative endpoints:
- `GET /api/admin/stations/:id/songs`: Lists all songs currently assigned to the station's collection, total count, currently playing song, and daemon health.
- `POST /api/admin/stations/:id/songs`: Adds one or more songs from the Supabase library by UUID.
- `DELETE /api/admin/stations/:id/songs/:songId`: Removes a song from the station collection (preserves the song in the master library).
- `GET /api/admin/stations/:id/status`: Provides real-time operational status (online/offline, total songs, currently playing title/artist, duration, last poll timestamp).

---

## 5. Potential Risks & Mitigation Matrix

| Risk | Impact | Mitigation Strategy |
|---|:---:|---|
| **Channel 7 disruption during deployment** | High | Use an isolated Liquidsoap container (`pulsecast-liquidsoap-ch6`), separate telnet port (1235), and separate cache directory. Channel 7 container and daemon are never stopped or restarted. |
| **Empty collection causing Liquidsoap crash** | Medium | `radio_ch6.liq` implements `fallback(track_sensitive=false, [ch6_queue, blank()])`. If no tracks are pushed, continuous silence frames are emitted, preserving the Icecast stream connection. |
| **Excessive Supabase Storage API requests** | Low | The daemon only polls once per track change (~every 3–4 minutes). Cached files in `cache_ch6` are reused when valid, avoiding redundant downloads. |
| **Consecutive song repetition** | Low | The dispatcher actively tracks `lastPlayedSongId` and filters it out of the candidate pool whenever $\ge 2$ songs are present. |
| **Database migration issues** | Low | The migration script `backend/sql/station_songs_migration.sql` creates a new table with `IF NOT EXISTS` and does not touch any existing table schemas or records. |

---

## 6. Detailed Implementation & Verification Roadmap

### Stage B — Implementation (Post-Approval)
1. **Database**:
   - Create `backend/sql/station_songs_migration.sql` (additive table `public.station_songs`).
   - Run migration against Supabase database.
2. **Backend API**:
   - Implement `stationSongService.js` with collection management, random shuffle selection, repeat prevention, and stats.
   - Update `streamingService.js` to dispatch Station 6 via random collection.
   - Add routes in `backend/src/routes/admin.js` (`/api/admin/stations/:id/songs`).
   - Update `stationController.js` to support station collection queries.
3. **Radio Pipeline Files**:
   - Create `radio/radio_ch6.liq` (Liquidsoap script for Channel 6).
   - Create `radio/pulsecast_ch6_daemon.py` (daemon for Channel 6).
   - Update `radio/docker-compose.yml` to declare the additive `liquidsoap-ch6` service.
   - Update `radio/.env.example` with Channel 6 configuration parameters.
4. **Admin Portal UI**:
   - Add Channel 6 song management tab / modal in React frontend (`frontend/admin/stations.html` & `frontend/js/admin.js`).
   - Add Channel 6 song management in Flutter Admin Portal (`mobile/lib/features/admin/`).

### Stage C — Testing
- Unit tests for random shuffle, duplicate prevention, empty collection fallback, and immediate repeat avoidance.
- End-to-end simulation of song addition and removal during active playback.
- Regression verification: verify Channel 7 and stations 1–5 continue operating with 0 issues.

### Stage D — Production Deployment
- Apply Caddy reverse proxy update on EC2.
- Start `pulsecast-liquidsoap-ch6` and `pulsecast_ch6_daemon.py`.
- Update station 6 `stream_url` to `https://pulsecast.duckdns.org/channel6.mp3` in Supabase.
- Verify public HTTPS stream on web, mobile, and external players.

---

## 7. Approval Gate

> [!IMPORTANT]
> In accordance with Stage A instructions, **no production infrastructure, server files, or database tables have been modified yet**.  
> Please review this inspection report and architecture design. Once you grant approval, we will immediately proceed to **Stage B: Implementation**.

