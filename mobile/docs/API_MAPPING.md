# PulseCast Mobile API Mapping & Integration Reference

> **Important**: This document reflects the exact endpoints, HTTP methods, headers, authentication guards, payload formats, and response structures implemented in the PulseCast backend. No endpoints or fields have been invented.

Base URL (Production): `https://internet-radio-stream.onrender.com`  
Base URL (Local Development): `http://10.0.2.2:5000` (Android Emulator) / `http://localhost:5000` (iOS Simulator)

---

## 1. Authentication & Security Architecture

### Authentication Mechanism
- **JWT Header**: `Authorization: Bearer <token>`
- **Cookie Fallback**: `token=<jwt_cookie>` (HttpOnly, set automatically by browser)
- **Token Format**: Standard JSON Web Token (HS256)
- **Token Claims**:
  ```json
  {
    "id": 1,
    "email": "listener@pulsecast.com",
    "role": "listener",
    "iat": 1730000000,
    "exp": 1730604800
  }
  ```
- **Token Validity**: 7 days (`JWT_EXPIRES_IN=7d`)

### Role-Based Access Control (RBAC)
- `listener`: Default role. Can view stations, upcoming tracks, program schedules, and manage user favourites.
- `admin`: Elevated role (`role === 'admin'`). Access to station CRUD, song library uploads/edits/deletions/signed-urls, and schedule calendar management.

### Mobile Token Storage
- Store JWT securely using `flutter_secure_storage` (Android Keystore / iOS Keychain).
- Attach token via Dio interceptor to all requests requiring authentication.

---

## 2. API Endpoints Reference

### A. System & Health

#### `GET /api/health`
- **Description**: Verifies backend server and Supabase PostgreSQL database connectivity.
- **Access**: Public
- **Request Headers**: None
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "status": "healthy",
    "timestamp": "2026-11-01T16:00:00.000Z",
    "uptime": 1234.56,
    "environment": "production",
    "database": {
      "connected": true,
      "driver": "supabase",
      "target": "supabase.co"
    }
  }
  ```

---

### B. Authentication (`/api/auth`)

#### `POST /api/auth/register`
- **Description**: Registers a new listener account.
- **Access**: Public (Rate-limited: 5 requests / 15 minutes)
- **Request Headers**: `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "name": "Jane Doe",
    "email": "jane@example.com",
    "password": "SecurePassword123!"
  }
  ```
  - Validation rules:
    - `name`: 2 to 100 characters.
    - `email`: valid email address format.
    - `password`: at least 8 characters, containing at least 1 uppercase letter, 1 lowercase letter, and 1 number.
- **Response `201 Created`**:
  ```json
  {
    "success": true,
    "message": "Account registered successfully.",
    "token": "eyJhbGciOi...",
    "user": {
      "id": 3,
      "name": "Jane Doe",
      "email": "jane@example.com",
      "role": "listener",
      "created_at": "2026-11-01T16:00:00.000Z"
    }
  }
  ```
- **Error Responses**:
  - `400 Bad Request`: Validation failure.
    ```json
    { "success": false, "message": "Validation failed.", "errors": ["Password must be at least 8 characters long..."] }
    ```
  - `409 Conflict`: Email already exists.
    ```json
    { "success": false, "message": "An account with this email address already exists." }
    ```

#### `POST /api/auth/login`
- **Description**: Authenticates user and returns JWT token.
- **Access**: Public (Rate-limited: 5 requests / 15 minutes)
- **Request Headers**: `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "email": "listener@pulsecast.com",
    "password": "ListenerPass123!"
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "message": "Signed in successfully.",
    "token": "eyJhbGciOi...",
    "user": {
      "id": 2,
      "name": "Alex Rivera",
      "email": "listener@pulsecast.com",
      "role": "listener",
      "created_at": "2026-10-29T06:59:57+00:00"
    }
  }
  ```
- **Error Responses**:
  - `400 Bad Request`: Email/password missing or malformed.
  - `401 Unauthorized`: Invalid credentials.
    ```json
    { "success": false, "message": "Invalid email or password." }
    ```

#### `POST /api/auth/logout`
- **Description**: Clears authentication session cookie.
- **Access**: Authenticated (`Authorization: Bearer <token>`)
- **Response `200 OK`**:
  ```json
  { "success": true, "message": "Signed out successfully." }
  ```

#### `GET /api/auth/me`
- **Description**: Returns profile of currently authenticated user.
- **Access**: Authenticated (`Authorization: Bearer <token>`)
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "user": {
      "id": 2,
      "name": "Alex Rivera",
      "email": "listener@pulsecast.com",
      "role": "listener",
      "created_at": "2026-10-29T06:59:57+00:00"
    }
  }
  ```
- **Error Response**:
  - `401 Unauthorized`: Missing or invalid token.

---

### C. Stations & Public Streams (`/api/stations`)

#### `GET /api/stations`
- **Description**: Lists active radio stations.
- **Access**: Optional Authentication.
  - If authenticated, each station object includes `is_favourite: true|false`.
  - Admin users may pass `?all=true` to include inactive stations.
- **Query Parameters**:
  - `genre` (string, optional): Filter by genre (e.g. `Rock`, `Vaporwave`).
  - `search` (string, optional): Search across station name and description.
  - `all` (string, optional, admin only): `true` to list inactive stations.
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "count": 6,
    "data": [
      {
        "id": 1,
        "name": "Radio Paradise (Main Mix)",
        "description": "High-fidelity eclectic rock, indie, world and acoustic streaming live 24/7.",
        "genre": "Eclectic / Rock",
        "stream_url": "https://stream.radioparadise.com/mp3-128",
        "artwork_url": "assets/station-artwork.svg",
        "is_active": true,
        "is_favourite": false,
        "created_at": "2026-10-29T06:59:57+00:00",
        "updated_at": "2026-10-29T09:01:56+00:00"
      },
      {
        "id": 2,
        "name": "Nightwave Plaza",
        "description": "24/7 internet radio broadcast dedicated to vaporwave, future funk and ambient electronic soundscapes.",
        "genre": "Vaporwave / Electronic",
        "stream_url": "https://radio.plaza.one/mp3",
        "artwork_url": "assets/station-artwork.svg",
        "is_active": true,
        "is_favourite": true,
        "created_at": "2026-10-29T06:59:57+00:00",
        "updated_at": "2026-10-29T09:02:02+00:00"
      },
      {
        "id": 4,
        "name": "KEXP Seattle Independent",
        "description": "Curated independent music broadcast from Seattle, Washington.",
        "genre": "Alternative / Indie",
        "stream_url": "https://kexp.streamguys1.com/kexp128.mp3",
        "artwork_url": "assets/station-artwork.svg",
        "is_active": true,
        "is_favourite": false,
        "created_at": "2026-10-29T06:59:57+00:00",
        "updated_at": "2026-10-31T16:36:16.24303+00:00"
      },
      {
        "id": 5,
        "name": "SomaFM Groove Salad",
        "description": "A nicely chilled plate of ambient/downtempo beats and grooves.",
        "genre": "Ambient / Downtempo",
        "stream_url": "https://ice1.somafm.com/groovesalad-128-mp3",
        "artwork_url": "assets/station-artwork.svg",
        "is_active": true,
        "is_favourite": false,
        "created_at": "2026-10-29T06:59:57+00:00",
        "updated_at": "2026-10-31T16:36:13.613251+00:00"
      },
      {
        "id": 6,
        "name": "PulseCast Radio",
        "description": "Automated radio with random music playback",
        "genre": "Mixed",
        "stream_url": "http://localhost:8000/pulsecast.mp3",
        "artwork_url": null,
        "is_active": true,
        "is_favourite": false,
        "created_at": "2026-10-29T12:28:35+00:00",
        "updated_at": "2026-10-29T12:28:35+00:00"
      },
      {
        "id": 7,
        "name": "PulseCast Radio (AWS)",
        "description": "Automated radio with random music playback",
        "genre": "Mixed",
        "stream_url": "https://pulsecast.duckdns.org/pulsecast.mp3",
        "artwork_url": null,
        "is_active": true,
        "is_favourite": false,
        "created_at": "2026-10-30T04:19:39+00:00",
        "updated_at": "2026-10-30T04:33:43+00:00"
      }
    ]
  }
  ```

#### `GET /api/stations/:id`
- **Description**: Returns details of a single station by numeric ID.
- **Access**: Optional Authentication.
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "data": {
      "id": 7,
      "name": "PulseCast Radio (AWS)",
      "description": "Automated radio with random music playback",
      "genre": "Mixed",
      "stream_url": "https://pulsecast.duckdns.org/pulsecast.mp3",
      "artwork_url": null,
      "is_active": true,
      "is_favourite": false
    }
  }
  ```

#### `GET /api/stations/:id/schedules`
- **Description**: Returns published program schedules for the specified station.
- **Access**: Optional Authentication (Admin can pass `?all=true` to include unpublished drafts).
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "station": {
      "id": 1,
      "name": "Radio Paradise (Main Mix)"
    },
    "count": 3,
    "data": [
      {
        "id": 1,
        "station_id": 1,
        "title": "Morning Acoustic Awakening",
        "description": "Gentle acoustic melodies, indie folk and morning coffee accompaniment.",
        "category": "Music",
        "schedule_date": "2026-10-31",
        "start_time": "09:00",
        "end_time": "12:00",
        "is_published": true,
        "created_at": "2026-10-29T06:59:57+00:00"
      }
    ]
  }
  ```

#### `GET /api/stations/:id/tracks`
- **Description**: Returns the currently playing track and the queue of upcoming songs for a station.
- **Access**: Public
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "station": {
      "id": 1,
      "name": "Radio Paradise (Main Mix)"
    },
    "total_tracks": 5,
    "now_playing": {
      "id": 1,
      "station_id": 1,
      "title": "Teardrop",
      "artist": "Massive Attack",
      "album": "Mezzanine",
      "duration": "05:30",
      "stream_url": null,
      "play_order": 1,
      "status": "playing",
      "created_at": "2026-10-29T06:59:57+00:00"
    },
    "up_next": [
      {
        "id": 2,
        "station_id": 1,
        "title": "Karma Police",
        "artist": "Radiohead",
        "album": "OK Computer",
        "duration": "04:24",
        "stream_url": null,
        "play_order": 2,
        "status": "queued",
        "created_at": "2026-10-29T06:59:57+00:00"
      }
    ],
    "all_tracks": [ ... ]
  }
  ```

---

### D. User Favourites (`/api/favourites`)

#### `GET /api/favourites`
- **Description**: Lists all favourite stations saved by the current user.
- **Access**: Authenticated (`Authorization: Bearer <token>`)
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "count": 1,
    "data": [
      {
        "id": 2,
        "name": "Nightwave Plaza",
        "description": "24/7 internet radio broadcast dedicated to vaporwave, future funk and ambient electronic soundscapes.",
        "genre": "Vaporwave / Electronic",
        "stream_url": "https://radio.plaza.one/mp3",
        "artwork_url": "assets/station-artwork.svg",
        "is_active": true,
        "is_favourite": true,
        "favourited_at": "2026-10-29T06:59:57+00:00"
      }
    ]
  }
  ```

#### `POST /api/favourites/:stationId`
- **Description**: Adds a station to user's favourites (idempotent; prevents duplicate entries).
- **Access**: Authenticated (`Authorization: Bearer <token>`)
- **Response `201 Created` / `200 OK`**:
  ```json
  {
    "success": true,
    "message": "Station \"Nightwave Plaza\" added to your favourites.",
    "station_id": 2
  }
  ```

#### `DELETE /api/favourites/:stationId`
- **Description**: Removes a station from user's favourites.
- **Access**: Authenticated (`Authorization: Bearer <token>`)
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "message": "Station removed from your favourites.",
    "station_id": 2
  }
  ```

---

### E. Admin Station Management (`/api/admin/stations`)

All endpoints in this section require `role === 'admin'`.

#### `POST /api/admin/stations`
- **Description**: Creates a new station record.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Request Body**:
  ```json
  {
    "name": "Chillhop Beats",
    "description": "Lo-fi hip hop and study beats 24/7.",
    "genre": "Lofi / Chillhop",
    "stream_url": "https://stream.chillhop.com/live.mp3",
    "artwork_url": "assets/station-artwork.svg",
    "is_active": true
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "success": true,
    "message": "Station created successfully.",
    "data": {
      "id": 8,
      "name": "Chillhop Beats",
      "description": "Lo-fi hip hop and study beats 24/7.",
      "genre": "Lofi / Chillhop",
      "stream_url": "https://stream.chillhop.com/live.mp3",
      "artwork_url": "assets/station-artwork.svg",
      "is_active": true
    }
  }
  ```

#### `PUT /api/admin/stations/:id`
- **Description**: Updates station metadata or stream URL.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Request Body**: Partial or full fields (`name`, `description`, `genre`, `stream_url`, `artwork_url`, `is_active`).
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "message": "Station updated successfully.",
    "data": { ... }
  }
  ```

#### `PATCH /api/admin/stations/:id/status`
- **Description**: Toggles or sets station active state (`is_active`).
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Request Body** (optional):
  ```json
  { "is_active": false }
  ```
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "message": "Station status changed to inactive.",
    "data": { "id": 8, "is_active": false }
  }
  ```

#### `DELETE /api/admin/stations/:id`
- **Description**: Deletes a station by ID.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**:
  ```json
  { "success": true, "message": "Station \"Chillhop Beats\" was deleted successfully." }
  ```

---

### F. Admin Program Schedules (`/api/admin/schedules`)

All endpoints in this section require `role === 'admin'`.

#### `GET /api/admin/schedules`
- **Description**: Lists schedules across stations with calendar range filtering, recurring indicators, and assigned song counts.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Query Parameters**:
  - `from` (string YYYY-MM-DD): Start date of range.
  - `to` (string YYYY-MM-DD): End date of range.
  - `stationId` (int): Filter by station ID.
  - `status` ('published' | 'draft'): Filter by publication status.
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "count": 1,
    "data": [
      {
        "id": 1,
        "station_id": 1,
        "station_name": "Radio Paradise (Main Mix)",
        "station_genre": "Eclectic / Rock",
        "title": "Morning Acoustic Awakening",
        "description": "Gentle acoustic melodies, indie folk and morning coffee accompaniment.",
        "category": "Music",
        "schedule_date": "2026-10-31",
        "is_recurring": false,
        "start_time": "09:00",
        "end_time": "12:00",
        "is_published": true,
        "status": "published",
        "songs": [ ... ],
        "song_count": 5,
        "created_at": "2026-10-29T06:59:57+00:00"
      }
    ]
  }
  ```

#### `GET /api/admin/schedules/:id`
- **Description**: Fetches single schedule entry with complete assigned song list.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "data": {
      "id": 1,
      "station_id": 1,
      "station_name": "Radio Paradise (Main Mix)",
      "station_genre": "Eclectic / Rock",
      "title": "Morning Acoustic Awakening",
      "description": "...",
      "category": "Music",
      "schedule_date": "2026-10-31",
      "start_time": "09:00",
      "end_time": "12:00",
      "is_published": true,
      "status": "published",
      "songs": [ ... ],
      "total_songs": 5,
      "created_at": "2026-10-29T06:59:57+00:00"
    }
  }
  ```

#### `POST /api/admin/schedules`
- **Description**: Creates a new program schedule with automatic conflict detection and track assignment.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Request Body**:
  ```json
  {
    "station_id": 1,
    "title": "Afternoon Jazz Club",
    "description": "Classic vinyl jazz selections.",
    "category": "Jazz",
    "schedule_date": "2026-11-02",
    "start_time": "14:00",
    "end_time": "16:00",
    "is_published": true,
    "songs": [
      {
        "id": "1a3825f2-1b65-4615-9f03-c42722d73551",
        "song_id": "1a3825f2-1b65-4615-9f03-c42722d73551",
        "source": "supabase",
        "title": "Take Five",
        "artist": "Dave Brubeck",
        "album": "Time Out",
        "duration": "05:24",
        "duration_seconds": 324
      }
    ]
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "success": true,
    "message": "Program schedule created successfully.",
    "data": { ... }
  }
  ```
- **Error Response `409 Conflict`**: Overlapping schedule on same station and date.
  ```json
  {
    "success": false,
    "conflict": true,
    "message": "Schedule conflict: Overlaps with existing published programme \"Morning Acoustic Awakening\" (09:00 - 12:00) on this station.",
    "conflicting_schedule": { "id": 1, "title": "...", "start_time": "09:00", "end_time": "12:00", "date": "2026-11-02" }
  }
  ```

#### `PUT /api/admin/schedules/:id` (or `PATCH`)
- **Description**: Updates schedule details, timing, publication status, and assigned tracks.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**: Updated schedule object.

#### `DELETE /api/admin/schedules/:id`
- **Description**: Deletes a schedule entry and its playlist tracks.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**: `{ "success": true, "message": "Schedule deleted successfully." }`

#### `POST /api/admin/schedules/:id/duplicate`
- **Description**: Duplicates a schedule as a draft ("Copy of ...") along with its assigned playlist.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `201 Created`**: Duplicated draft schedule object.

#### `PATCH /api/admin/schedules/:id/publish`
- **Description**: Toggles publication status between published and draft. Performs conflict check if publishing.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**: `{ "success": true, "message": "Schedule is now Published.", "is_published": true }`

---

### G. Schedule Playlist Management (`/api/admin/schedules/:id/tracks`)

All endpoints in this section require `role === 'admin'`.

#### `GET /api/admin/schedules/:id/tracks`
- **Description**: Returns ordered playlist tracks assigned to a specific schedule.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "count": 2,
    "data": [
      {
        "id": "c13d7890-...",
        "schedule_id": 1,
        "song_id": "1a3825f2-1b65-4615-9f03-c42722d73551",
        "track_id": null,
        "source": "supabase",
        "title": "Teardrop",
        "artist": "Massive Attack",
        "album": "Mezzanine",
        "duration": "05:30",
        "duration_seconds": 330,
        "stream_url": null,
        "play_order": 1,
        "created_at": "2026-10-31T12:00:00.000Z"
      },
      {
        "id": "c13d7891-...",
        "schedule_id": 1,
        "song_id": null,
        "track_id": 2,
        "source": "general",
        "title": "Karma Police",
        "artist": "Radiohead",
        "album": "OK Computer",
        "duration": "04:24",
        "duration_seconds": 264,
        "stream_url": null,
        "play_order": 2,
        "created_at": "2026-10-31T12:00:00.000Z"
      }
    ]
  }
  ```

#### `PUT /api/admin/schedules/:id/tracks` (or `POST`)
- **Description**: Replaces or reorders the entire schedule playlist.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Request Body**:
  ```json
  {
    "tracks": [
      {
        "id": "1a3825f2-1b65-4615-9f03-c42722d73551",
        "song_id": "1a3825f2-1b65-4615-9f03-c42722d73551",
        "source": "supabase",
        "title": "Teardrop",
        "artist": "Massive Attack",
        "duration": "05:30",
        "duration_seconds": 330
      }
    ]
  }
  ```
- **Response `200 OK`**: `{ "success": true, "count": 1, "message": "Schedule playlist updated successfully.", "data": [ ... ] }`

#### `DELETE /api/admin/schedules/:id/tracks/:trackId`
- **Description**: Removes a single track from the schedule playlist without deleting the song from the library.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**: `{ "success": true, "count": 0, "message": "Track removed from schedule playlist. Library song remains intact.", "data": [] }`

---

### H. Music Library Management (`/api/admin/songs`)

All endpoints in this section require `role === 'admin'`.

#### `GET /api/admin/songs`
- **Description**: Lists, filters, searches, and paginates songs from the private Supabase Storage music library.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Query Parameters**:
  - `page` (int, default 1)
  - `limit` (int, default 20, max 100)
  - `search` or `q` (string): Search title, artist, album.
  - `activeOnly` (boolean): Only active songs (`true`).
  - `sortBy` ('title' | 'artist' | 'album' | 'created_at' | 'duration_seconds')
  - `order` ('asc' | 'desc')
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "count": 7,
    "total": 7,
    "page": 1,
    "limit": 20,
    "totalPages": 1,
    "stats": {
      "totalSongs": 7,
      "activeSongs": 7,
      "totalStorageBytes": 52428800,
      "totalDurationSeconds": 1540
    },
    "data": [
      {
        "id": "1a3825f2-1b65-4615-9f03-c42722d73551",
        "title": "Teardrop",
        "artist": "Massive Attack",
        "album": "Mezzanine",
        "duration": "05:30",
        "duration_seconds": 330,
        "mime_type": "audio/mpeg",
        "file_size_bytes": 7890123,
        "file_hash": "5ffb16cb0285a508d4a5e80fc0c88e10f328b3f28a9a4c77178790b87767126c",
        "storage_bucket": "pulsecast-music-library",
        "storage_path": "library/1a3825f2-1b65-4615-9f03-c42722d73551/teardrop.mp3",
        "original_filename": "teardrop.mp3",
        "created_by": 1,
        "is_active": true,
        "created_at": "2026-10-31T10:00:00.000Z",
        "updated_at": "2026-10-31T10:00:00.000Z"
      }
    ]
  }
  ```

#### `GET /api/admin/songs/stats`
- **Description**: Returns aggregate statistics for the entire song library.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "data": {
      "totalSongs": 7,
      "activeSongs": 7,
      "totalStorageBytes": 52428800,
      "totalDurationSeconds": 1540
    }
  }
  ```

#### `GET /api/admin/songs/:id`
- **Description**: Retrieves single song metadata by UUID.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**: `{ "success": true, "data": { ... } }`

#### `POST /api/admin/songs`
- **Description**: Uploads a single audio file (MP3, WAV, AAC, up to 50MB) to private Supabase Storage, extracts metadata, verifies duplicates via normalized filename and SHA-256 hash.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Content-Type**: `multipart/form-data`
- **Form Fields**:
  - `file` (binary, required): Audio file.
  - `title` (string, optional): Song title (defaults to ID3 tag or filename).
  - `artist` (string, optional): Artist name.
  - `album` (string, optional): Album name.
- **Response `201 Created`**:
  ```json
  {
    "success": true,
    "message": "Song \"Teardrop\" uploaded successfully.",
    "data": {
      "id": "2b4936f3-...",
      "title": "Teardrop",
      "artist": "Massive Attack",
      "album": "Mezzanine",
      "duration": "05:30",
      "duration_seconds": 330,
      "file_size_bytes": 7890123,
      "file_hash": "...",
      "storage_bucket": "pulsecast-music-library",
      "storage_path": "library/2b4936f3-.../teardrop.mp3",
      "original_filename": "teardrop.mp3",
      "is_active": true,
      "created_at": "2026-11-01T16:00:00.000Z"
    }
  }
  ```
- **Error Responses**:
  - `400 Bad Request`: Invalid MIME type, file too large (>50MB), or empty file.
  - `409 Conflict`: Duplicate filename or SHA-256 audio content hash detected.
    ```json
    {
      "success": false,
      "conflict": true,
      "duplicateType": "filename",
      "message": "This song already exists in your library.",
      "existing_song": { "id": "...", "title": "Teardrop", "original_filename": "teardrop.mp3" }
    }
    ```

#### `POST /api/admin/songs/bulk`
- **Description**: Bulk uploads up to 20 audio files with bounded concurrency and in-batch duplicate detection.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Content-Type**: `multipart/form-data`
- **Form Fields**: `files` (array of audio binaries), `concurrency` (int, default 3).
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "total": 3,
    "successful": 2,
    "duplicates": 1,
    "duplicate_filename": 1,
    "duplicate_content": 0,
    "failed": 0,
    "data": [
      { "filename": "track1.mp3", "success": true, "status": "uploaded", "song": { ... } },
      { "filename": "track2.mp3", "success": false, "status": "duplicate_filename", "duplicateType": "filename", "message": "This song already exists in your library." }
    ]
  }
  ```

#### `PATCH /api/admin/songs/:id`
- **Description**: Updates editable song metadata (`title`, `artist`, `album`, `is_active`).
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Request Body**:
  ```json
  {
    "title": "Teardrop (Remastered)",
    "artist": "Massive Attack",
    "album": "Mezzanine (Deluxe)",
    "is_active": true
  }
  ```
- **Response `200 OK`**: Updated song object.

#### `DELETE /api/admin/songs/:id`
- **Description**: Soft deletes (archives, sets `is_active = false`) by default, or permanently deletes if `?permanent=true`. Checks if song is assigned to any schedule before permanent deletion.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Query Parameters**:
  - `permanent` (boolean, optional): `true` to delete from storage and database.
  - `force` (boolean, optional): `true` to override schedule assignment check.
- **Response `200 OK`**: `{ "success": true, "message": "Song permanently deleted." }`
- **Error Response `409 Conflict`**: Song is assigned to active schedules.
  ```json
  {
    "success": false,
    "conflict": true,
    "assignedCount": 2,
    "message": "Cannot delete song: currently assigned to 2 program schedule(s). Archive it instead or remove it from schedules first."
  }
  ```

#### `GET /api/admin/songs/:id/signed-url` (or `POST`)
- **Description**: Generates a short-lived (default 300 seconds / 5 minutes) signed URL for preview or in-app playback of private Supabase audio.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Query / Body Parameters**:
  - `expiresIn` (int, optional): Expiration in seconds (default 300).
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "data": {
      "songId": "1a3825f2-1b65-4615-9f03-c42722d73551",
      "title": "Teardrop",
      "artist": "Massive Attack",
      "signedUrl": "https://fzusdbnznnhksvxvylzg.supabase.co/storage/v1/object/sign/pulsecast-music-library/library/1a3825f2-.../teardrop.mp3?token=...",
      "expiresIn": 300
    }
  }
  ```
- **Security Rule**: The mobile app must never store this signed URL permanently; generate on-demand for playback or preview.

#### `GET /api/admin/songs/search`
- **Description**: Unified music catalogue search with source separation between General Library (`upcoming_tracks` catalogue) and Supabase Library (`songs` table).
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Query Parameters**:
  - `q` or `search` (string): Search query string.
  - `source` ('general' | 'supabase' | 'all'): Filter by catalogue source.
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "count": 2,
    "source": "all",
    "data": [
      {
        "id": "1a3825f2-1b65-4615-9f03-c42722d73551",
        "song_id": "1a3825f2-1b65-4615-9f03-c42722d73551",
        "track_id": null,
        "title": "Teardrop",
        "artist": "Massive Attack",
        "album": "Mezzanine",
        "duration": "05:30",
        "duration_seconds": 330,
        "stream_url": null,
        "preview_url": "/api/admin/songs/1a3825f2-1b65-4615-9f03-c42722d73551/signed-url",
        "source": "supabase"
      },
      {
        "id": 1,
        "track_id": 1,
        "song_id": null,
        "title": "Teardrop",
        "artist": "Massive Attack",
        "album": "Mezzanine",
        "duration": "05:30",
        "duration_seconds": 330,
        "stream_url": null,
        "source": "general"
      }
    ]
  }
  ```

---

### I. Admin Track Queue Management (`/api/admin/tracks`)

All endpoints in this section require `role === 'admin'`.

#### `POST /api/admin/stations/:id/tracks`
- **Description**: Adds a track to a station's upcoming queue.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Request Body**:
  ```json
  {
    "title": "Karma Police",
    "artist": "Radiohead",
    "album": "OK Computer",
    "duration": "04:24",
    "stream_url": null,
    "play_order": 2,
    "status": "queued"
  }
  ```
- **Response `201 Created`**: Track object.

#### `PATCH /api/admin/tracks/:id/status`
- **Description**: Updates track status (`playing`, `queued`, `played`). Demotes prior playing tracks when setting a new track to `playing`.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Request Body**: `{ "status": "playing" }`
- **Response `200 OK`**: `{ "success": true, "message": "Track status updated to playing." }`

#### `DELETE /api/admin/tracks/:id`
- **Description**: Deletes a track from the station queue.
- **Access**: Admin (`Authorization: Bearer <token>`)
- **Response `200 OK`**: `{ "success": true, "message": "Track removed from queue." }`

---

### J. Streaming Bridge & Dispatcher (`/api/streaming`)

#### `GET /api/streaming/stations/:stationId/current-broadcast`
- **Description**: Resolves currently active broadcast program metadata for a station.
- **Access**: Public
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "station_id": 1,
    "has_schedule": true,
    "schedule": {
      "id": 1,
      "title": "Morning Acoustic Awakening",
      "start_time": "09:00",
      "end_time": "12:00",
      "total_tracks": 5
    }
  }
  ```

#### `GET /api/streaming/stations/:stationId/next-track`
- **Description**: Real-time station-aware playback dispatcher (Asia/Kolkata timezone). Generates short-lived signed URLs for Supabase tracks on-demand.
- **Access**: Server-to-Server (`x-radio-token: <RADIO_STREAMING_KEY>`) OR Admin JWT (`Authorization: Bearer <token>`).
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "has_schedule": true,
    "fallback": false,
    "station_id": 7,
    "station_name": "PulseCast Radio (AWS)",
    "schedule_id": 1,
    "schedule_title": "Morning Acoustic Awakening",
    "start_time": "09:00",
    "end_time": "12:00",
    "play_order": 1,
    "index": 0,
    "next_index": 1,
    "total_tracks": 5,
    "cursor": 1,
    "track_id": "1a3825f2-1b65-4615-9f03-c42722d73551",
    "song_id": "1a3825f2-1b65-4615-9f03-c42722d73551",
    "source": "supabase",
    "title": "Teardrop",
    "artist": "Massive Attack",
    "album": "Mezzanine",
    "duration": "05:30",
    "duration_seconds": 330,
    "audio_url": "https://fzusdbnznnhksvxvylzg.supabase.co/storage/v1/object/sign/pulsecast-music-library/library/.../teardrop.mp3?token=...",
    "is_signed_url": true,
    "expires_in": 300,
    "created_at": "2026-11-01T16:00:00.000Z"
  }
  ```

---

## 3. General Library vs Supabase Library Isolation Rule

| Feature / Dimension | General Library | Supabase Library |
| :--- | :--- | :--- |
| **Primary Storage** | Database table `upcoming_tracks` | Private Supabase Storage bucket `pulsecast-music-library` |
| **Metadata Record** | MySQL / Postgres `upcoming_tracks` | Postgres `songs` table |
| **ID Type** | Auto-incrementing Integer (`1, 2, ...`) | UUID v4 (`crypto.randomUUID()`) |
| **Audio Access** | Public stream URL (`stream_url`) | Ephemeral signed URL (expires in 300s) |
| **Upload Flow** | Add metadata and stream URL directly | Multipart audio file upload + SHA-256 deduplication |
| **Radio Streaming Bridge** | Fallback catalogue for general radio | **Strict Requirement** for EC2 radio broadcast |
| **Isolation Constraint** | **Must NEVER enter the EC2 Supabase streaming queue** | **Strictly enforced** by `pulsecast_sync_daemon.py` |

---

## 4. Error Handling & Status Codes Summary

- `200 OK`: Successful retrieval or update.
- `201 Created`: Resource successfully created (registration, station, song, schedule).
- `400 Bad Request`: Validation failure, invalid ID, file size > 50MB, or invalid MIME type.
- `401 Unauthorized`: Missing or invalid token, expired session, or wrong credentials.
- `403 Forbidden`: Authenticated user does not possess `admin` role.
- `404 Not Found`: Station, schedule, track, or song ID not found.
- `409 Conflict`: Duplicate email on registration, duplicate filename/SHA-256 on song upload, schedule time overlap, or attempt to delete song assigned to active schedules.
- `429 Too Many Requests`: Exceeded auth rate limit (5 attempts / 15 minutes).
- `500 Internal Server Error`: Unhandled exception or storage connection failure.

