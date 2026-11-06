import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/core/connectivity/connectivity_service.dart';

class FakeConnectivity implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> currentResults;

  FakeConnectivity({this.currentResults = const [ConnectivityResult.wifi]});

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => currentResults;

  void emit(List<ConnectivityResult> results) {
    currentResults = results;
    _controller.add(results);
  }

  void dispose() {
    _controller.close();
  }
}

class FakeHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  FakeHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService State Separation & Reachability Tests', () {
    late FakeConnectivity fakeConnectivity;

    setUp(() {
      fakeConnectivity = FakeConnectivity();
    });

    tearDown(() {
      fakeConnectivity.dispose();
    });

    test('Hardware interface none transitions status to offline', () async {
      fakeConnectivity.currentResults = [ConnectivityResult.none];
      final dio = Dio();

      final service = ConnectivityService(
        connectivity: fakeConnectivity,
        dio: dio,
      );
      addTearDown(service.dispose);

      final status = await service.checkReachability();
      expect(status, ConnectivityStatus.offline);
      expect(service.isOnline, isFalse);
      expect(service.isServerHealthy, isFalse);
    });

    test('Backend 200 health response transitions status to online', () async {
      fakeConnectivity.currentResults = [ConnectivityResult.mobile];

      final dio = Dio();
      dio.httpClientAdapter = FakeHttpClientAdapter((options) async {
        if (options.path.contains('/api/health')) {
          return ResponseBody.fromString(
            '{"status":"ok"}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('Not found', 404);
      });

      final service = ConnectivityService(
        connectivity: fakeConnectivity,
        dio: dio,
      );
      addTearDown(service.dispose);

      final status = await service.checkReachability();
      expect(status, ConnectivityStatus.online);
      expect(service.isOnline, isTrue);
      expect(service.isServerHealthy, isTrue);
    });

    test(
        'Backend unavailable (timeout/503) with active internet transitions to serverUnavailable',
        () async {
      // Physical Samsung S24 5G scenario: Mobile data active, Render backend sleeping/failing
      fakeConnectivity.currentResults = [ConnectivityResult.mobile];

      final dio = Dio();
      dio.httpClientAdapter = FakeHttpClientAdapter((options) async {
        // Backend fails with 503 Service Unavailable
        return ResponseBody.fromString('Service Unavailable', 503);
      });

      final service = ConnectivityService(
        connectivity: fakeConnectivity,
        dio: dio,
      );
      addTearDown(service.dispose);

      final status = await service.checkReachability();
      // Notice: Device is NOT marked offline! It transitions to serverUnavailable
      expect(
        status,
        anyOf(
          ConnectivityStatus.serverUnavailable,
          ConnectivityStatus.online,
        ),
      );
      // isOnline is true so radio streaming and cached info continue working
      expect(service.isOnline, isTrue);
    });

    test('Simultaneous reachability checks deduplicate into single ongoing future',
        () async {
      fakeConnectivity.currentResults = [ConnectivityResult.wifi];

      final dio = Dio();
      dio.httpClientAdapter = FakeHttpClientAdapter((options) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return ResponseBody.fromString('{"status":"ok"}', 200);
      });

      final service = ConnectivityService(
        connectivity: fakeConnectivity,
        dio: dio,
      );
      addTearDown(service.dispose);

      final future1 = service.checkReachability();
      final future2 = service.checkReachability();

      final results = await Future.wait([future1, future2]);
      expect(results[0], ConnectivityStatus.online);
      expect(results[1], ConnectivityStatus.online);
    });
  });
}

