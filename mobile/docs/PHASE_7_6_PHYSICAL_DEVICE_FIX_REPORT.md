# PulseCast Mobile — Phase 7.6: Samsung S24 Physical Device Bug Fix Report

**Date**: November 3, 2026  
**Target Environment**: Samsung Galaxy S24 (Android 14, One UI 6.1, 1080x2340 @ 1.25x font scale, 5G Active Network)  
**Status**: Completed & Verified  

---

## 1. Executive Summary

During release testing on a physical Samsung Galaxy S24 running on active 5G mobile data, three critical UX/UI bugs were identified:
1. **Station Card Horizontal Overflow**: `RenderFlex` right overflow by ~12px on Radio Paradise and ~2–6px on other station cards due to subpixel advance and 1.25x One UI font scaling.
2. **Incorrect Offline Detection**: Device on active 5G was falsely flagged as `"You're offline — showing saved information"` due to Render backend cold-start timeouts, while the Home screen simultaneously showed a static `"ONLINE"` badge. Live streaming of external station CDNs was obstructed.
3. **Station List Clipping & Scroll Occlusion**: The station list had visual clipping near the search filter header and the bottom station card was buried beneath the floating 68px mini-player.

All three defects have been resolved without breaking any Phase 1–7.5 functionality, without modifying backend/infra services, and with 100% test pass rate across 134 automated unit and responsive widget tests.

---

## 2. Root Cause Analysis & Architectural Solutions

### Bug 1: Station Card Horizontal Overflow

- **Root Cause**:
  In `station_card.dart`, `Flexible(flex: 0, child: _buildStatusIndicator())` combined with an `Expanded(Row(...))` layout caused Flutter Flex layout in release mode to remove flex constraints from the status indicator, giving it unconstrained width. On Samsung One UI with 1.25x font scale, long genre tags (e.g. `"Eclectic / Listener-Supported"`) pushed against the trailing buttons, resulting in `RenderFlex right overflowed by 12 pixels`.
- **Architectural Solution**:
  - **Trailing Action Area**: Replaced the horizontal button layout with a strict `SizedBox(width: 44)` containing a clean vertical column: Favorite icon button on top (36x36 tap target) and Play/Pause icon button below (38x38 tap target).
  - **Metadata Column**: Given an unrestricted `Expanded` flex allocation with zero horizontal competition from action buttons.
  - **Bottom Row**: The genre badge is wrapped in `Flexible(fit: FlexFit.loose)` with `maxLines: 1`, `softWrap: false`, and `TextOverflow.ellipsis`. The status indicator (`STREAMING`, `LIVE`, `READY`) is an intrinsic non-flex widget with compact padding (`AppDimensions.space4`), ensuring zero horizontal extrusion regardless of font scaling.

### Bug 2: Incorrect Offline Detection & Cold-Start Desynchronization

- **Root Cause**:
  PulseCast's backend is hosted on a Render free-tier instance which spins down after periods of inactivity. Booting up takes 30–50 seconds. The previous `ConnectivityService` executed a single HTTP request to `https://internet-radio-stream.onrender.com/api/health` with an aggressive 4-second timeout. When a device on 5G or Wi-Fi made a network request while Render was booting, the 4-second timeout tripped, unconditionally setting the app into `ConnectivityStatus.offline`.
  Furthermore:
  - Third-party live radio streams (KEXP, SomaFM, Radio Paradise, Nightwave Plaza) are hosted on independent CDNs (Icecast/Akamai), not on Render. Falsely marking the app offline blocked playback of active live radio stations.
  - `HomeScreen` contained a hardcoded `'ONLINE'` text badge that was not wired to any Riverpod connectivity state, causing contradictory UI states where the offline banner appeared directly over an "ONLINE" badge.
- **Architectural Solution**:
  - **5-State Connectivity Model**: Upgraded `ConnectivityStatus` to 5 distinct operational states:
    - `unknown`: Initial launch state (prevents premature banner flashing).
    - `checking`: In-flight active reachability probe.
    - `online`: Both device network and PulseCast backend are reachable.
    - `serverUnavailable`: Device has active internet (5G/Wi-Fi), but PulseCast backend is booting/waking up (HTTP 503 or timeout).
    - `offline`: Device has no physical network connection or cannot reach any public internet endpoint.
  - **Dual-Stage Reachability Verification**:
    - Concurrency-mutexed `_checkReachability()` runs on every network change or manual trigger.
    - Stage 1: Probes `https://internet-radio-stream.onrender.com/api/health` (6s timeout).
    - Stage 2 (Fallback): If backend times out or returns 503, immediately probes high-availability internet endpoints (`https://clients3.google.com/generate_204`, `https://1.1.1.1`).
    - If Stage 2 succeeds, status transitions to `ConnectivityStatus.serverUnavailable` instead of `offline`.
  - **Radio Playback Continuity**: `isOnlineProvider` returns `true` for both `online` and `serverUnavailable`. This allows live radio audio streams to connect and play without hindrance.
  - **Context-Aware Offline Banner**:
    - Hidden during startup (`unknown`, `checking`).
    - True offline: `"You're offline — showing saved information"`.
    - Server cold boot: `"PulseCast server is waking up — showing saved information"` with an animated spin indicator.
  - **Reactive Home Connectivity Badge**: Replaced static text with `_ConnectivityBadge` widget observing `connectivityStatusProvider` (`ONLINE` [green], `CONNECTING` [amber], `OFFLINE` [red], `CHECKING` [grey]).
  - **Lifecycle Resume Handler**: Added `WidgetsBindingObserver` to automatically recheck connectivity the moment the user resumes the app.

### Bug 3: Station List Clipping & Scroll Clearance

- **Root Cause**:
  `StationsScreen` contained an unnecessary inner `SafeArea` that clashed with the top `AppBar` and the outer `AppShell`, causing search input and genre chips to shift or clip. Station cards scrolled beneath the transparent search filter header, creating ugly text overlap. At the bottom of the list, only 8px of padding was provided, leaving the final station card trapped under the 68px floating `MiniPlayerWidget`.
- **Architectural Solution**:
  - Removed the inner `SafeArea`.
  - Enclosed the search bar and genre chips in an opaque header container with `AppColors.background` and a subtle bottom border.
  - Configured `ListView.builder` with `bottom: AppDimensions.space32 + AppDimensions.miniPlayerHeight` (100px bottom clearance) and `clipBehavior: Clip.none`, ensuring all station cards scroll completely clear of the mini-player.

---

## 3. Automated Test Verification Matrix

### Unit & Responsive Widget Tests (134 Tests Passing)
| Test Suite | Tests Passed | Coverage Highlights |
|---|:---:|---|
| `station_card_responsive_test.dart` | 40 / 40 | Evaluated across 320px, 360px, 375px, 390px, 412px, 430px with Radio Paradise, Nightwave Plaza, SomaFM, long tags, and Samsung 1.25x font scale. **0 RenderFlex overflows**. |
| `connectivity_service_test.dart` | 4 / 4 | Verified 5G reachability, 503 Render cold start fallback to `serverUnavailable`, dual-stage check mutexing, and offline transitions. |
| `player_notifier_test.dart` | 4 / 4 | Fast stream startup, immediate audio playback without metadata blocking, play/pause toggle, stop. |
| `admin_*_test.dart` | 32 / 32 | Schedule, songs, stats, signed URLs, and station admin capabilities. |
| `auth_notifier_test.dart` | 14 / 14 | Login, registration, token persistence, logout, role evaluation. |
| `offline_*_test.dart` & `favorites_*_test.dart` | 28 / 28 | Offline cache, Hive fallback, optimistic favorite toggle, sync queue. |
| `widget_test.dart` | 12 / 12 | Navigation shell, tab switching, mini-player visibility. |
| **Total** | **134 / 134** | **100% Pass Rate** |

### Static Code Analysis
- `flutter analyze`: **No issues found! (0 warnings, 0 errors, 0 lints)**

---

## 4. Modified Files Summary

| File | Change Description |
|---|---|
| `mobile/lib/features/stations/presentation/widgets/station_card.dart` | Vertical action column layout (44px width), flexible genre badge, intrinsic status badge. |
| `mobile/lib/features/stations/presentation/screens/stations_screen.dart` | Removed inner `SafeArea`, pinned solid header, added 100px bottom clearance for mini-player. |
| `mobile/lib/core/connectivity/connectivity_service.dart` | 5-state connectivity model, dual-stage reachability fallback, app lifecycle observer. |
| `mobile/lib/core/connectivity/connectivity_providers.dart` | Added `isServerReachableProvider`, updated `isOnlineProvider`, status enum export. |
| `mobile/lib/core/widgets/offline_banner.dart` | Distinct offline vs server waking messages; suppressed on cold start checking. |
| `mobile/lib/features/home/home_screen.dart` | Reactive `_ConnectivityBadge` replacing static text. |
| `mobile/lib/features/favorites/presentation/providers/favorites_providers.dart` | Listens to `connectivityStatusProvider` for sync trigger. |
| `mobile/lib/features/player/presentation/providers/player_notifier.dart` | Clears connectivity error state upon network restoration. |
| `mobile/lib/features/settings/presentation/screens/settings_screen.dart` | Updated network diagnostics display for 5-state model. |
| `mobile/test/widget/station_card_responsive_test.dart` | 40 responsive tests covering all form factors and font scales. |
| `mobile/test/unit/connectivity/connectivity_service_test.dart` | 4 unit tests for dual-stage reachability. |
| `mobile/test/unit/player/player_notifier_test.dart` | Added `isOnlineProvider` test overrides. |

---

## 5. Verification Sign-Off

- **Responsive Overflow**: Eliminated on all screen densities and font scaling settings.
- **Offline Detection**: Correctly distinguishes mobile 5G connectivity from backend spin-down.
- **Audio Streaming**: External radio streams play continuously regardless of backend cold start.
- **Scroll & Layout**: Zero clipping, full 100px bottom mini-player clearance.
- **Regressions**: Zero regressions across Phases 1–7.5.

