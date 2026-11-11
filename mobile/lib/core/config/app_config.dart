import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Environment and Application Configuration for PulseCast
class AppConfig {
  AppConfig._();

  /// Default production API base URL hosted on Render
  static const String _defaultProdApiUrl =
      'https://internet-radio-stream.onrender.com';

  /// Compile-time configurable API Base URL via:
  /// flutter run --dart-define=API_BASE_URL=https://your-custom-url.com
  static const String _configuredApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Compile-time flag to force local backend development
  static const bool useLocalBackend = bool.fromEnvironment(
    'USE_LOCAL_BACKEND',
    defaultValue: false,
  );

  /// Resolves the active API base URL depending on platform & environment
  static String get apiBaseUrl {
    if (_configuredApiUrl.isNotEmpty) {
      return _configuredApiUrl.endsWith('/')
          ? _configuredApiUrl.substring(0, _configuredApiUrl.length - 1)
          : _configuredApiUrl;
    }

    if (useLocalBackend) {
      if (kIsWeb) return 'http://localhost:5000';
      if (Platform.isAndroid) return 'http://10.0.2.2:5000';
      return 'http://localhost:5000';
    }

    return _defaultProdApiUrl;
  }

  /// Default primary EC2 Icecast live radio stream (Station 7)
  static const String defaultStreamUrl =
      'https://pulsecast.duckdns.org/pulsecast.mp3';

  /// Channel 6 public HTTPS live radio stream URL (PulseCast Radio 24/7 Automated)
  static const String channel6StreamUrl = String.fromEnvironment(
    'CHANNEL_6_STREAM_URL',
    defaultValue: 'https://prevent-productions-satisfy-minimal.trycloudflare.com/pulsecast.mp3',
  );

  /// Network Timeouts (milliseconds)
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  /// Application Metadata
  static const String appName = 'PulseCast';
  static const String appVersion = '1.0.0';
  static const String userAgent = 'PulseCast-Mobile/1.0.0';
}

