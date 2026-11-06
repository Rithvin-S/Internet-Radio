import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../config/app_config.dart';

/// Separated connectivity states according to Phase 7.6 specifications
enum ConnectivityStatus {
  unknown,
  checking,
  online,
  offline,
  serverUnavailable,
}

/// Service monitoring device network interface, internet reachability,
/// and live PulseCast backend health.
class ConnectivityService with WidgetsBindingObserver {
  final Connectivity _connectivity;
  final Dio _dio;

  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;
  ConnectivityStatus get currentStatus => _currentStatus;

  /// True if the device has working internet (backend online or server unavailable but internet active)
  bool get isOnline =>
      _currentStatus == ConnectivityStatus.online ||
      _currentStatus == ConnectivityStatus.serverUnavailable;

  /// True if PulseCast backend server is confirmed healthy
  bool get isServerHealthy => _currentStatus == ConnectivityStatus.online;

  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  Completer<ConnectivityStatus>? _ongoingCheck;

  ConnectivityService({
    Connectivity? connectivity,
    Dio? dio,
  })  : _connectivity = connectivity ?? Connectivity(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
              ),
            ) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  void _init() {
    // Perform initial reachability check immediately on startup
    checkReachability();

    // Listen to hardware network interface changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _updateStatus(ConnectivityStatus.offline);
      } else {
        // Network interface available (Wi-Fi, 5G, 4G, Ethernet) — verify real reachability
        checkReachability();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Recheck connectivity when app returns to foreground
      checkReachability(force: true);
    }
  }

  /// Verifies connectivity with mutex deduplication to prevent concurrent health check storms
  Future<ConnectivityStatus> checkReachability({bool force = false}) async {
    if (_ongoingCheck != null && !_ongoingCheck!.isCompleted) {
      return _ongoingCheck!.future;
    }

    final completer = Completer<ConnectivityStatus>();
    _ongoingCheck = completer;

    // Transition to checking state only if not already verified online
    if (_currentStatus == ConnectivityStatus.unknown) {
      _updateStatus(ConnectivityStatus.checking);
    }

    try {
      // Step 1: Verify hardware network interface
      final results = await _connectivity.checkConnectivity();
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _updateStatus(ConnectivityStatus.offline);
        completer.complete(ConnectivityStatus.offline);
        return ConnectivityStatus.offline;
      }

      // Step 2: Test backend health endpoint
      bool backendReachable = false;
      try {
        final response = await _dio.get(
          '/api/health',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        backendReachable =
            response.statusCode != null && response.statusCode! < 500;
      } catch (_) {
        backendReachable = false;
      }

      if (backendReachable) {
        _updateStatus(ConnectivityStatus.online);
        completer.complete(ConnectivityStatus.online);
        return ConnectivityStatus.online;
      }

      // Step 3: Backend failed or timed out (e.g. Render cold start or 503).
      // Check if general internet is reachable before declaring the device offline!
      final internetReachable = await _checkGeneralInternet();
      if (internetReachable) {
        _updateStatus(ConnectivityStatus.serverUnavailable);
        completer.complete(ConnectivityStatus.serverUnavailable);
        return ConnectivityStatus.serverUnavailable;
      } else {
        _updateStatus(ConnectivityStatus.offline);
        completer.complete(ConnectivityStatus.offline);
        return ConnectivityStatus.offline;
      }
    } catch (_) {
      _updateStatus(ConnectivityStatus.offline);
      completer.complete(ConnectivityStatus.offline);
      return ConnectivityStatus.offline;
    } finally {
      _ongoingCheck = null;
    }
  }

  /// Lightweight HTTPS internet reachability check against standard public endpoint
  Future<bool> _checkGeneralInternet() async {
    try {
      final probeDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      // Lightweight Google generate_204 endpoint or Cloudflare trace
      final response = await probeDio.get(
        'https://clients3.google.com/generate_204',
        options: Options(
          validateStatus: (status) => status != null && status >= 200 && status < 400,
        ),
      );

      return response.statusCode == 204 ||
          (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 400);
    } catch (_) {
      // Fallback probe to Cloudflare 1.1.1.1 DNS over HTTPS
      try {
        final probeDio2 = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        final response2 = await probeDio2.get(
          'https://1.1.1.1',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        return response2.statusCode != null && response2.statusCode! < 500;
      } catch (_) {
        return false;
      }
    }
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _statusController.close();
  }
}
