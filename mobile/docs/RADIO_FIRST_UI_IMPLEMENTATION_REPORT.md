# PulseCast Mobile — Radio-First Experience & Navigation Redesign Report

**Date:** November 6, 2026  
**Status:** COMPLETED & VERIFIED  
**Scope:** Strictly inside `mobile/`  

---

## 1. Executive Summary

This phase transformed the PulseCast mobile application into a dedicated, radio-first internet audio streaming experience. The initial landing dashboard has been replaced with an immersive **Radio Screen** that makes **Channel 6 — PulseCast Radio** the primary default station on launch.

All modifications were implemented exclusively within `mobile/`, preserving:
- Single persistent `RadioAudioHandler` (background playback, lockscreen media controls).
- Phase 7.5 low-latency instant stream startup architecture.
- Account-scoped favorites and metadata caching.
- Zero modifications to React frontend, Node backend, Supabase DB/buckets, or streaming servers.

---

## 2. Key Architecture & UI Changes

### 2.1 Dedicated Radio Screen (`RadioScreen`)
- **Primary Landing Screen:** The app now opens directly onto `RadioScreen` (`RouteNames.radio = '/'`), removing the legacy Home dashboard.
- **Branding & Status:** Top header featuring the distinct `PULSE` / `CAST` gradient badge, reactive live connectivity badge (`ONLINE`, `CONNECTING`, `OFFLINE`), and quick settings button.
- **Station Artwork & Vinyl Simulation:** Displays a prominent 220px album artwork container with rounded corners and subtle shadow. When artwork is absent, a custom animated/wave fallback renders with station initials.
- **LIVE Badge & Playback State:** Dynamic badge glowing with Aurora gradients when streaming, paired with textual status indicators (`Streaming Live`, `Buffering Audio...`, `Paused / Ready`, `Offline`).
- **Metadata & Favorite Action:** Real-time track title, artist name, and a one-tap favorite button allowing listeners to save currently playing tracks directly into their personal favorites collection.
- **Instant Controls:** 72px play/pause button with glowing gradient, skip buttons (previous / next station cycling), and metadata refresh button.
- **Station Switcher Carousel:** Horizontal quick-switch carousel displaying available stations and their genres, allowing one-tap switching without leaving the radio tuner.

### 2.2 Channel 6 as Primary Default & Public Stream URL Resolution
- **Default Station:** Configured Station #6 (Channel 6 — PulseCast Radio) as the primary default on startup.
- **Production URL Resolution:** Added `AppConfig.channel6StreamUrl` defaulting to `https://pulsecast.duckdns.org/channel6.mp3` (configurable via `--dart-define=CHANNEL_6_STREAM_URL=...`).
- **Domain Layer Normalization:** In `Station.effectiveStreamUrl` and `RadioAudioHandler.playStation`, any legacy development URL (`http://localhost:8000/...`) for Station 6 is resolved to the public HTTPS stream endpoint.
- **Honest Loading/Offline State:** In offline or connecting states, genuine error notifications with retry actions are rendered without false playback simulation.

### 2.3 Startup Autoplay Implementation
- **Preference Controlled:** Added `autoplayOnLaunch` to `UserSettings` (default: `true`).
- **Launch Lifecycle:** Handled via post-frame initialization in `RadioScreen` without triggering blocking network calls or unmanaged timers in isolated widget tests.
- **Offline Guard:** Playback only attempts to auto-start when active network connectivity is confirmed (`ref.read(isOnlineProvider) == true`).

### 2.4 Bottom Navigation Redesign & MiniPlayer Visibility
- **5 Bottom Navigation Tabs:**
  1. `Radio` (icon: `Icons.radio_rounded`)
  2. `Stations` (icon: `Icons.podcasts_rounded`)
  3. `Library` (icon: `Icons.queue_music_rounded`)
  4. `Favourites` (icon: `Icons.favorite_outline_rounded`)
  5. `Settings` (icon: `Icons.settings_outlined`)
- **Removed Empty Profile Tab:** The placeholder Profile tab was completely retired.
- **Adaptive MiniPlayer (`AppShell`):** `MiniPlayerWidget` is hidden on tab 0 (Radio Screen) via `if (navigationShell.currentIndex != 0)` to eliminate duplicate controls and visual clutter, while remaining persistent across all other tabs when a station is active.

### 2.5 Settings & Account Management
- **Account & Profile Section:** Embedded at the top of `SettingsScreen`, displaying:
  - User name and authenticated email.
  - Role pill badge (`ADMIN` in amber / `LISTENER` in cyan).
  - Admin Portal shortcut button for administrators.
  - Sign In CTA card for unauthenticated guest listeners.
- **Confirmed Sign Out Action:**
  - Interactive confirmation dialog (`LogoutConfirmationDialog.show`).
  - Clears secure storage JWT tokens, resets Riverpod auth state, and redirects to `/login`.
- **Default Station Selector:** Allows listeners to set their preferred default station, featuring Channel 6 as the system default.

---

## 3. Verification & Quality Assurance

### 3.1 Static Analysis
```bash
flutter analyze
```
- **Result:** `No issues found!` (0 errors, 0 warnings).

### 3.2 Automated Test Suite
```bash
flutter test
```
- **Result:** `134/134 passed` (100% pass rate).
- **Test Coverage:**
  - `test/widget_test.dart`: App smoke test & shell navigation.
  - `test/unit/routing/role_based_routing_test.dart`: RBAC redirects and settings destination verification.
  - `test/unit/settings/settings_repository_test.dart`: Defaults persistence and factory reset tests.
  - `test/unit/stations/station_repository_test.dart`: Station models and local fallback tests.
  - `test/widget/stations_and_player_widgets_test.dart`: Station cards, responsive layouts, and MiniPlayer tests.
  - `test/widget/favorites_and_settings_test.dart`: Settings sections, playback toggles, and favorites tabs.

### 3.3 Android Compilation
- **Debug Build:**
  ```bash
  flutter build apk --debug
  ```
  - **Result:** `√ Built build\app\outputs\flutter-apk\app-debug.apk` (59.8s).
- **Release Build:**
  ```bash
  flutter build apk --release
  ```
  - **Result:** `√ Built build\app\outputs\flutter-apk\app-release.apk (55.9MB)` (31.2s).

---

## 4. Modified Files List

1. `mobile/lib/core/config/app_config.dart` — Public HTTPS URL configuration for Channel 6.
2. `mobile/lib/features/stations/domain/models/station.dart` — `effectiveStreamUrl` getter and stream URL resolution.
3. `mobile/lib/features/player/services/radio_audio_handler.dart` — Playback stream routing using `effectiveStreamUrl`.
4. `mobile/lib/features/settings/domain/models/user_settings.dart` — Defaults for `autoplayOnLaunch` (`true`) and `defaultStationId` (`null`).
5. `mobile/lib/features/settings/presentation/screens/settings_screen.dart` — Account section, role badges, confirmed logout, and Channel 6 picker.
6. `mobile/lib/features/player/presentation/providers/player_notifier.dart` — Startup playback context restoration without blocking network calls.
7. `mobile/lib/features/radio/presentation/screens/radio_screen.dart` — New dedicated Radio Screen UI with Channel 6 default and quick switcher.
8. `mobile/lib/features/home/home_screen.dart` — Aliased to `RadioScreen` for backward compatibility.
9. `mobile/lib/routing/route_names.dart` — Added `radio = '/'`, removed `profile`.
10. `mobile/lib/routing/app_shell.dart` — 5-tab navigation and conditional MiniPlayer.
11. `mobile/lib/routing/app_router.dart` — Router routes update, settings branch, and role-based redirects.
12. `mobile/lib/features/admin/admin_dashboard_screen.dart` — Updated back navigation to `/settings`.
13. `mobile/test/widget_test.dart` — Updated shell expectations.
14. `mobile/test/unit/routing/role_based_routing_test.dart` — Updated redirect assertions to `/settings`.
15. `mobile/test/unit/settings/settings_repository_test.dart` — Updated defaults assertions.

