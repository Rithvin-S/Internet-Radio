import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cache/cache_providers.dart';
import 'sync_queue.dart';
import 'sync_service.dart';

/// Provider for the SyncService manager
final syncServiceProvider = Provider<SyncService>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  final service = SyncService(cacheService);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Reactive Notifier tracking the latest SyncStatus
class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final service = ref.watch(syncServiceProvider);

    void listener() {
      state = service.statusNotifier.value;
    }

    service.statusNotifier.addListener(listener);
    ref.onDispose(() => service.statusNotifier.removeListener(listener));

    return service.status;
  }

  void setStatus(SyncStatus status) {
    state = status;
  }
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

/// Provider reporting the count of pending offline mutations
final pendingSyncCountProvider = Provider.autoDispose<int>((ref) {
  final service = ref.watch(syncServiceProvider);
  // Re-read when syncStatus changes
  ref.watch(syncStatusProvider);
  return service.getQueue().length;
});

