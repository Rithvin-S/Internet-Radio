# PulseCast — Cross-Platform Mobile Application

A modern, high-fidelity Internet Radio Streaming & Administrative Mobile Application for PulseCast, built with Flutter & Dart.

Supports both **Android** and **iOS** with native background audio playback, lockscreen controls, and role-based administration.

---

## 1. Features

### Listener Experience
- **Live Internet Radio Streaming**: Seamless continuous streaming from Icecast and third-party radio mounts.
- **Background Media Playback**: Native foreground playback services for Android (`AudioService`) and iOS (`AVAudioSession`).
- **Persistent Player & Mini-Player**: Uninterrupted aud
io playback across screen transitions.
- **Station Catalogue & Discovery**: Browse, filter by genre, and stream live stations.
- **Program Schedules**: Google Calendar-style station program guide and timetable.
- **Upcoming Track Queue**: Real-time *Now Playing* and *Up Next* track metadata.
- **Favourites**: Save favourite radio stations and tracks.

### Admin Experience
- **Role-Based Security**: Strict JWT and backend verification ensuring only administrators access management tools.
- **Station Management**: Create, edit, toggle active status, and delete radio stations.
- **Song Library Management**:
  - Direct integration with private Supabase Storage (`pulsecast-music-library`).
  - Automatic audio metadata extraction (ID3 tags, duration, bitrates).
  - Cryptographic SHA-256 duplicate prevention.
  - Ephemeral signed URL generation for audio preview.
  - Strict isolation between General Library and Supabase Library.
- **Schedule Management**: Create, edit, duplicate, and publish program schedules with automated time-overlap conflict prevention.

---

## 2. Technology Stack

- **Framework**: Flutter 3.32+
- **Language**: Dart 3.8+
- **State Management**: `flutter_riverpod`
- **Networking**: `dio`
- **Routing**: `go_router`
- **Audio Engine**: `just_audio`, `audio_service`, `audio_session`
- **Storage**: `flutter_secure_storage`, `shared_preferences`
- **Image Caching**: `cached_network_image`

---

## 3. Project Structure

```
mobile/
├── android/                  # Native Android configuration (permissions, AudioService)
├── ios/                      # Native iOS configuration (Info.plist, Background audio)
├── assets/
│   ├── images/               # Logos and station artwork
│   ├── icons/                # Vector media and indicator icons
│   └── fonts/
├── docs/
│   ├── API_MAPPING.md        # Comprehensive backend endpoint reference
│   └── IOS_BUILD_GUIDE.md    # macOS and Xcode build documentation
├── lib/
│   ├── main.dart             # Application entrypoint & ProviderScope
│   ├── core/
│   │   ├── config/           # AppConfig & base URL resolution
│   │   ├── constants/        # AppColors, AppDimensions, AppStrings
│   │   ├── network/          # Dio client, AuthInterceptor
│   │   ├── theme/            # PulseCast Aurora dark theme & typography
│   │   └── utils/            # Formatters and validators
│   ├── models/               # Station, Track, Schedule, Song models
│   ├── services/             # Audio, Auth, Storage, and API services
│   ├── providers/            # Riverpod state providers
│   ├── routing/              # AppRouter (GoRouter) & RouteNames
│   └── features/             # Feature modules (auth, home, player, stations, etc.)
└── test/                     # Unit and widget test suite
```

---

## 4. Implementation Status & Roadmap

| Phase | Milestone | Status | Details |
| :---: | :--- | :---: | :--- |
| **Phase 1** | Inspection & Architecture Analysis | ✅ Complete | Zero-backend change policy, API mapping, data model isolation. |
| **Phase 2** | Flutter Environment & Setup | ✅ Complete | Modular architecture, Aurora dark theme, Riverpod, routing. |
| **Phase 3** | Authentication & RBAC | ✅ Complete | JWT handling, secure storage, listener & admin role redirection. |
| **Phase 4** | Stations & Persistent Audio Player | ✅ Complete | Singleton `RadioAudioHandler`, background playback, lock-screen controls, live stream reconnection. |
| **Phase 5** | Music Library & Admin Portal | ✅ Complete | Listener library, Admin dashboard, Supabase song library & upload, station/schedule management, playlist sequencing, ephemeral audio previews. |
| **Phase 6** | Offline Caching, Favorites & Sync | ✅ Complete | TTL metadata caching (stations: 12h, tracks: 2h, schedules: 30m), artwork caching, remote station sync (`/api/favourites`), local song favorites (strict General vs Supabase isolation), sync queue with conflict resolution, connectivity monitor, global offline banner, settings & preferences. |
| **Phase 7** | Cross-Platform Testing & Polish | ✅ Complete | Account-scoped favorites isolation & legacy migration, R8/ProGuard optimization, dark splash theme, haptic feedback, release APK verification (55.9MB), 92/92 tests passing. |
| **Phase 7.5** | UI Responsiveness & Playback Performance | ✅ Complete | Tuned low-latency audio buffer (600ms), warm codec reuse (<1.3s station switch), decoupled async NowPlaying metadata, in-memory catalog persistence (0ms tab switch), 94/94 tests passing. |

---

## 5. Getting Started

### Prerequisites
- Flutter SDK (3.32+)
- Android Studio / Android SDK (Platform 34+)
- Xcode 15+ (for iOS, on macOS)

### Run Locally
```bash
cd mobile
flutter pub get
flutter run
```

### Environment Configuration
To run against the local development backend instead of production Render:
```bash
# Android Emulator (points to http://10.0.2.2:5000)
flutter run --dart-define=USE_LOCAL_BACKEND=true

# iOS Simulator / Desktop (points to http://localhost:5000)
flutter run --dart-define=USE_LOCAL_BACKEND=true
```

To specify a custom API base URL:
```bash
flutter run --dart-define=API_BASE_URL=https://your-custom-backend.com
```

### Build APK
```bash
flutter build apk --debug
# or for release:
flutter build apk --release
```
