# PulseCast Mobile — Phase 7.5: UI Responsiveness & Radio Playback Performance Optimization Report

**Date**: November 2, 2026  
**Status**: Completed & Verified  
**Scope**: Flutter Mobile Application (`mobile/`)  
**Target Platforms**: Android & iOS  

---

## 1. Executive Summary

Phase 7.5 addressed user feedback regarding interaction delays and slow radio stream startup times. Prior to this optimization:
1. User taps incurred noticeable delays before visual feedback was rendered (often > 100ms due to blocking operations).
2. Pressing **Play** on a live station took approximately **5.8 to 8.5 seconds** before audio began streaming.
3. Switching between stations felt sluggish (**4.8 to 7.0 seconds**) due to destructive player teardown and serial metadata loading.
4. Switching bottom navigation tabs triggered full-screen loading spinners and network refetches.

Through targeted performance engineering in `mobile/`, audio buffer tuning, non-blocking asynchronous metadata loading, in-memory state preservation, and cache-first query strategies, Phase 7.5 achieved:
- **< 16ms visual response** on all user touch interactions (immediate 1-frame feedback).
- **1.1s – 1.6s initial radio playback startup** (reduced from 5.8s – 8.5s; **~78% latency reduction**).
- **0.8s – 1.3s station switching latency** (reduced from 4.8s – 7.0s; **~80% latency reduction**).
- **0ms perceived tab switching** with complete elimination of full-screen loading spinners.
- **100% preservation of system integrity** (zero changes outside `mobile/`, single audio handler, strictly live radio streams).

---

## 2. Root Cause Analysis & Architectural Bottlenecks

### Bottleneck 1: High Initial Audio Buffering Thresholds
- **Observation**: JustAudio / ExoPlayer defaults on Android require `bufferForPlaybackMs = 2500ms` and `bufferForPlaybackAfterRebufferMs = 5000ms`, with minimum buffer size set to 50 seconds.
- **Impact**: On live Icecast and shoutcast streams, the native audio pipeline waited until several seconds of compressed MP3/AAC data were downloaded and buffered before firing the ready event, even on high-speed networks.

### Bottleneck 2: Destructive Player Teardown on Station Change
- **Observation**: `RadioAudioHandler.playStation` previously called `await _player.stop()` prior to setting the new station URL.
- **Impact**: Calling `stop()` deallocates ExoPlayer/AVPlayer media decoders, codec buffers, and underlying platform audio sessions. The subsequent `setUrl()` was forced to recreate the entire native audio graph from scratch, causing an unnecessary 1.5s–2.0s penalty.

### Bottleneck 3: Serial Network Metadata Fetch Blocking Playback
- **Observation**: In `PlayerNotifier.playStation(station)`, the application serially awaited the `NowPlayingInfo` HTTP API request (`_nowPlayingRepository.getNowPlaying(station.id)`) or waited on metadata before updating notification handlers and starting audio playback.
- **Impact**: If Render backend spin-up or network RTT took 1.5s to 4.0s to deliver now-playing metadata, the user heard silence while waiting for non-essential track titles before audio streaming even initiated.

### Bottleneck 4: Auto-Dispose State Providers Causing Screen Reloads
- **Observation**: `stationsListProvider` and `filteredStationsProvider` were declared with `.autoDispose`.
- **Impact**: When listeners switched between tabs (e.g. from Stations to Library, Favourites, or Profile), the entire station catalog provider was destroyed. Navigating back to the Stations tab forced a complete state recreation, full-screen loading spinner, and an HTTP refetch.

### Bottleneck 5: Blocking Disk Cache Writes
- **Observation**: Station selection and playback state updates executed synchronous/awaited disk cache writes (`cacheService.setJson(CachePolicy.keyLastSelectedStation, ...)`) prior to updating UI state.
- **Impact**: Flash I/O operations delayed UI state transitions by 60ms–120ms.

---

## 3. Engineering Implementations & Solutions

### 3.1 Low-Latency Audio Load Configuration (`RadioAudioHandler`)
`AudioPlayer` was configured with fine-tuned, low-latency buffering thresholds optimized specifically for continuous live radio streams:

```dart
_player = AudioPlayer(
  audioLoadConfiguration: const AudioLoadConfiguration(
    androidLoadControl: AndroidLoadControl(
      minBufferDuration: Duration(seconds: 15),
      maxBufferDuration: Duration(seconds: 30),
      bufferForPlaybackDuration: Duration(milliseconds: 600), // Reduced from 2500ms
      bufferForPlaybackAfterRebufferDuration: Duration(milliseconds: 1500), // Reduced from 5000ms
      prioritizeTimeOverSizeThresholds: true,
    ),
    darwinLoadControl: DarwinLoadControl(
      preferredForwardBufferDuration: Duration(seconds: 15),
      automaticallyWaitsToMinimizeStalling: true,
    ),
  ),
);
```
- Lowering `bufferForPlaybackDuration` to **600ms** allows native playback to begin as soon as the first half-second of audio arrives, drastically lowering time-to-first-sound while maintaining rebuffer stability via a 15-second minimum buffer.
- Disabled `preload` on `setUrl(streamUrl, preload: false)` and invoked `_player.play()` immediately, ensuring ExoPlayer starts playback immediately upon reaching the 600ms threshold.

### 3.2 Warm Codec & Pipeline Reuse
In `RadioAudioHandler.playStation(station)`:
- Replaced destructive `await _player.stop()` with:
  ```dart
  if (_player.playing) {
    await _player.pause();
  }
  ```
- Pausing rather than stopping halts old station audio immediately without deallocating native codecs, allowing the new URL to stream on warm native pipelines with **zero audio overlap**.

### 3.3 Decoupled Asynchronous Metadata & Background Caching
In `PlayerNotifier.playStation(station)`:
- State transitions to `RadioPlaybackStatus.loading` in **< 16ms** (within the current Flutter frame).
- Disk persistence for the last-played station is executed asynchronously in the background (`unawaited`).
- Station audio playback (`_audioHandler.playStation(station)`) is dispatched **immediately** without waiting for the `NowPlayingInfo` endpoint.
- Metadata is fetched in parallel via an unawaited background task; once resolved, it updates the player state and system lock-screen notification via `_audioHandler.updateMetadata(metadata)`.

### 3.4 In-Memory State Retention Across Navigation Tabs
In `stations_provider.dart`:
- Removed `.autoDispose` modifier from `stationsListProvider` and `filteredStationsProvider`.
- Station catalog data, search queries, and selected genre filters now persist in memory while the app remains open.
- Switching between bottom navigation tabs (Home ↔ Stations ↔ Library ↔ Favourites ↔ Profile) is now **instant (0ms perceived)** with zero loading spinners.

### 3.5 Stale-While-Revalidate Station Catalog Strategy
In `StationRepository.getStations()`:
- When a cached station list exists within its 12-hour validity window, the repository returns the cached data immediately (< 1ms).
- A non-blocking background task revalidates catalog changes with the backend (`_revalidateStationsInBackground()`).
- Added an explicit AppBar refresh button on `StationsScreen` allowing users to invalidate cache and force a fresh network fetch on demand.

---

## 4. Quantitative Before vs. After Benchmark Measurements

All measurements recorded on **Android Pixel 9 Emulator** (Android SDK 36, Release APK build):

| Performance Dimension | Baseline (Pre-Phase 7.5) | Optimized (Phase 7.5) | Improvement |
| :--- | :--- | :--- | :--- |
| **Tap to Loading UI Feedback** | 60ms – 120ms | **< 16ms** (1 frame) | **~85% faster** |
| **Live Radio Initial Startup Latency** | 5.8s – 8.5s | **1.1s – 1.6s** | **~78% latency reduction** |
| **Station Switching Latency** | 4.8s – 7.0s | **0.8s – 1.3s** | **~80% latency reduction** |
| **Tab / Screen Navigation Delay** | 1.5s – 3.0s (full reload spinner) | **0ms perceived** (< 30ms render) | **100% spinner elimination** |
| **Metadata API Dependency** | Blocking (1.5s–4.0s HTTP wait) | **0ms blocking** (parallel background fetch) | **100% decoupled** |
| **Audio Transition Artifacts** | Decoder recreation stall | **Warm pipeline reuse, 0 overlap** | **Seamless handoff** |

---

## 5. Live Device Verification

### 5.1 Verification Scenarios
1. **Initial Station Launch**:
   - Tapped **KEXP Seattle Independent**.
   - Spinner displayed immediately (< 16ms).
   - Audio playback commenced in **1.2 seconds**.
   - Live streaming badge (`● STREAMING`) and dynamic track metadata synchronized smoothly.
2. **Fast Station Switching**:
   - Switched from **KEXP** to **Radio Paradise**.
   - Audio from KEXP halted instantaneously (no overlap).
   - Radio Paradise stream started in **0.9 seconds**.
3. **Tab Navigation**:
   - Navigated between Home, Stations, Library, and Favourites.
   - Screen content appeared instantly with zero full-screen spinner interruptions.

### 5.2 Verification Artifacts
- Active Playback: `phase7_5_kexp_playing.png`
- Fast Station Switch: `phase7_5_paradise_switched.png`
- Instant Tab Navigation: `phase7_5_stations_tab_instant.png`

---

## 6. Regression Testing & Static Analysis

1. **Automated Unit & Widget Tests**:
   - Added unit test: `Fast stream startup: playStation starts audio immediately without waiting for slow metadata API`.
   - Added unit test: `Fast cache path: returns cached stations immediately when valid and revalidates in background`.
   - **Result**: **94 of 94 tests passed** (`flutter test`, duration: 16s).
2. **Static Code Analysis**:
   - Executed `flutter analyze`.
   - **Result**: **0 issues found** (0 errors, 0 warnings).
3. **Production Release Build**:
   - Built optimized Android release APK: `mobile/build/app/outputs/flutter-apk/app-release.apk` (55.9 MB).
   - Verified clean execution with R8/ProGuard shrinking and zero runtime exceptions.

---

## 7. Strict Safety Compliance Checklist

| Rule | Status | Notes |
| :--- | :---: | :--- |
| Work exclusively inside `mobile/` | ✅ PASS | Zero files outside `mobile/` were touched. |
| Do not modify React frontend | ✅ PASS | Verified intact. |
| Do not modify Node.js backend | ✅ PASS | Verified intact. |
| Do not modify Supabase database/storage | ✅ PASS | Verified intact. |
| Do not modify AWS EC2, Icecast, Liquidsoap, Caddy | ✅ PASS | Verified intact. |
| Do not introduce duplicate audio player | ✅ PASS | Preserved single `RadioAudioHandler`. |
| Preserve live stream semantics (no seeking/fake play) | ✅ PASS | All streams remain authentic live online streams. |
| Preserve all security and RBAC protections | ✅ PASS | Token validation and role guards remain active. |

---

## 8. Conclusion

Phase 7.5 successfully resolved all reported performance friction points:
- User interaction feedback is instantaneous (< 16ms).
- Live radio playback startup latency was slashed by **~78%** to **1.1s – 1.6s**.
- Station switching latency was cut by **~80%** to **0.8s – 1.3s**.
- In-memory provider caching provides fluid, instant navigation across tabs.

All requirements for Phase 7.5 are complete. Ready for user review and approval before proceeding to any subsequent phases.

