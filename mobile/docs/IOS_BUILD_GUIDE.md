# PulseCast — iOS Setup, Configuration & Build Guide

This document details the iOS project structure, platform capabilities, and macOS/Xcode build instructions for PulseCast.

---

## 1. Prerequisites (macOS Environment)

To build and run PulseCast on iOS or the iOS Simulator, the following macOS tools are required:

- **Hardware**: Mac with Apple Silicon (M1/M2/M3/M4) or Intel processor.
- **Operating System**: macOS Sonoma (14.0+) or macOS Sequoia (15.0+).
- **Xcode**: Xcode 15.0 or Xcode 16+ (available via the Mac App Store).
- **Command Line Tools**:
  ```bash
  xcode-select --install
  sudo xcodebuild -runFirstLaunch
  ```
- **CocoaPods** (Dependency manager for iOS native plugins):
  ```bash
  sudo gem install cocoapods
  # or via Homebrew:
  brew install cocoapods
  ```
- **Flutter SDK**: Flutter 3.32+ with Dart 3.8+.

---

## 2. iOS Configuration Details

The iOS project structure has already been prepared inside `mobile/ios/`:

### A. Bundle Identifier
- Configured in `mobile/ios/Runner.xcodeproj/project.pbxproj`:
  ```
  PRODUCT_BUNDLE_IDENTIFIER = com.pulsecast.radio;
  ```
- App Display Name (`CFBundleDisplayName`): `PulseCast`

### B. Background Audio Capability
Internet radio playback requires the `audio` background mode. Configured in `mobile/ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```
This enables:
- Seamless background audio when the screen locks.
- Lock-screen Now Playing widget and playback controls.
- Control Center integration.
- Hardware volume and Bluetooth headset controls.

### C. Network Security (App Transport Security)
PulseCast supports standard HTTPS streams (`https://stream.radioparadise.com`, `https://pulsecast.duckdns.org/pulsecast.mp3`) as well as local HTTP dev mounts. Configured in `mobile/ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsArbitraryLoadsInMedia</key>
    <true/>
</dict>
```

---

## 3. Build & Run Instructions on macOS

### Step 1: Install CocoaPods Dependencies
Navigate to the iOS folder and install native pod dependencies (`audio_service`, `just_audio`, `flutter_secure_storage`, etc.):
```bash
cd mobile/ios
pod install
cd ..
```

### Step 2: Open Project in Xcode (Code Signing)
```bash
open ios/Runner.xcworkspace
```
1. In Xcode's project navigator, select the `Runner` target.
2. Navigate to the **Signing & Capabilities** tab.
3. Check **Automatically manage signing**.
4. Select your **Apple Developer Team**.
5. Verify the Bundle Identifier: `com.pulsecast.radio`.

### Step 3: Run on iOS Simulator
List available simulators:
```bash
flutter devices
```
Launch on simulator (e.g., iPhone 16 Pro):
```bash
flutter run -d "iPhone 16 Pro"
```

### Step 4: Run on Physical iOS Device
1. Connect iPhone via USB or Wi-Fi.
2. Trust the developer certificate on the iPhone under **Settings > General > VPN & Device Management**.
3. Run:
```bash
flutter run -d <device_id>
```

### Step 5: Build Release Archive (IPA)
```bash
flutter build ipa --release
```
The output `.ipa` and Xcode archive will be generated in `build/ios/ipa/` for distribution via Apple TestFlight or the App Store.

