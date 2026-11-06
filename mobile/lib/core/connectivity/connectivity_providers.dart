import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service.dart';

/// Provider for the singleton ConnectivityService
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Reactive Notifier tracking the latest ConnectivityStatus
class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  @override
  ConnectivityStatus build() {
    final service = ref.watch(connectivityServiceProvider);

    final sub = service.statusStream.listen((status) {
      state = status;
    });

    ref.onDispose(() => sub.cancel());

    return service.currentStatus;
  }

  /// Manually force a re-check of network and server reachability
  Future<ConnectivityStatus> checkNow() async {
    final service = ref.read(connectivityServiceProvider);
    state = ConnectivityStatus.checking;
    final status = await service.checkReachability(force: true);
    state = status;
    return status;
  }
}

final connectivityStatusProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
  ConnectivityNotifier.new,
);

/// Boolean provider indicating whether the device has a working internet connection.
/// Returns true when online, checking, unknown, or serverUnavailable (allows radio streaming).
/// Returns false strictly when the device is completely offline.
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status != ConnectivityStatus.offline;
});

/// Boolean provider indicating whether the PulseCast Render backend is confirmed reachable.
final isServerReachableProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status == ConnectivityStatus.online;
});
