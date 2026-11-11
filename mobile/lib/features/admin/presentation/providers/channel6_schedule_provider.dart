import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../stations/presentation/providers/stations_provider.dart';
import '../../data/channel6_schedule_repository.dart';
import '../../domain/models/channel6_schedule_state.dart';
import 'admin_providers.dart';

final channel6ScheduleRepositoryProvider =
    Provider<IChannel6ScheduleRepository>((ref) {
  return Channel6ScheduleRepository(
    storageService: ref.watch(secureStorageServiceProvider),
  );
});

final channel6ScheduleProvider = AsyncNotifierProvider<
    Channel6ScheduleNotifier, Channel6ScheduleState>(
  Channel6ScheduleNotifier.new,
);

/// Manages live Channel 6 queue state, drag-and-drop / up-down reordering,
/// and periodic timeline sync strictly for authenticated administrators.
class Channel6ScheduleNotifier extends AsyncNotifier<Channel6ScheduleState> {
  Timer? _refreshTimer;
  bool _disposed = false;
  bool _isMutating = false;

  @override
  Future<Channel6ScheduleState> build() async {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _refreshTimer?.cancel();
      _refreshTimer = null;
    });

    final authState = ref.watch(authNotifierProvider);
    if (!authState.isAuthenticated || !authState.isAdmin) {
      throw StateError('Administrator privileges required.');
    }

    _startAutoRefresh();
    final repo = ref.read(channel6ScheduleRepositoryProvider);
    return repo.getSchedule(streamUrl: _resolveChannel6StreamUrl());
  }

  String _resolveChannel6StreamUrl() {
    if (ref.exists(adminStationsListProvider)) {
      final adminStations = ref.read(adminStationsListProvider).asData?.value;
      if (adminStations != null) {
        for (final s in adminStations) {
          if (s.isChannel6) {
            final url = s.effectiveStreamUrl;
            if (url.isNotEmpty &&
                !url.contains('localhost') &&
                !url.contains('127.0.0.1')) {
              return url;
            }
          }
        }
      }
    }

    if (ref.exists(stationsListProvider)) {
      final publicStations = ref.read(stationsListProvider).asData?.value;
      if (publicStations != null) {
        for (final s in publicStations) {
          if (s.isChannel6) {
            final url = s.effectiveStreamUrl;
            if (url.isNotEmpty &&
                !url.contains('localhost') &&
                !url.contains('127.0.0.1')) {
              return url;
            }
          }
        }
      }
    }

    return AppConfig.channel6StreamUrl;
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    final interval = ref.read(metadataPollingIntervalProvider);
    if (interval == null) return;

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_disposed && !_isMutating) {
        unawaited(refreshSilently());
      }
    });
  }

  Future<void> refreshSilently() async {
    if (_disposed || _isMutating) return;
    try {
      final repo = ref.read(channel6ScheduleRepositoryProvider);
      final latest =
          await repo.getSchedule(streamUrl: _resolveChannel6StreamUrl());
      if (!_disposed && !_isMutating) {
        state = AsyncData(latest);
      }
    } catch (_) {
      // Preserve last valid snapshot on silent background poll failure
    }
  }

  Future<void> refresh() async {
    if (!state.hasValue) {
      state = const AsyncLoading();
    }
    try {
      final repo = ref.read(channel6ScheduleRepositoryProvider);
      final latest =
          await repo.getSchedule(streamUrl: _resolveChannel6StreamUrl());
      if (!_disposed) {
        state = AsyncData(latest);
      }
    } catch (e, st) {
      if (!_disposed) {
        state = AsyncError(e, st);
      }
    }
  }

  Future<void> enqueueTrack(String trackId) async {
    _isMutating = true;
    try {
      final repo = ref.read(channel6ScheduleRepositoryProvider);
      final updated = await repo.enqueueTrack(
        trackId,
        streamUrl: _resolveChannel6StreamUrl(),
      );
      if (!_disposed) {
        state = AsyncData(updated);
      }
    } finally {
      _isMutating = false;
    }
  }

  Future<void> enqueueTracks(List<String> trackIds) async {
    if (trackIds.isEmpty) return;
    _isMutating = true;
    try {
      final repo = ref.read(channel6ScheduleRepositoryProvider);
      final updated = await repo.enqueueTracks(
        trackIds,
        streamUrl: _resolveChannel6StreamUrl(),
      );
      if (!_disposed) {
        state = AsyncData(updated);
      }
    } finally {
      _isMutating = false;
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.asData?.value;
    if (current == null) return;

    final list = List<Channel6QueueItem>.from(current.queue);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex >= list.length || targetIndex == oldIndex) {
      return;
    }

    final moved = list.removeAt(oldIndex);
    list.insert(targetIndex, moved);
    final reindexed = [
      for (int i = 0; i < list.length; i++) list[i].copyWith(position: i + 1),
    ];

    // Optimistic update while syncing order to Channel 6 server
    state = AsyncData(current.copyWith(queue: reindexed));
    _isMutating = true;
    try {
      final repo = ref.read(channel6ScheduleRepositoryProvider);
      final updated = await repo.reorderQueue(
        reindexed.map((e) => e.itemId).toList(),
        streamUrl: _resolveChannel6StreamUrl(),
      );
      if (!_disposed) {
        state = AsyncData(updated);
      }
    } catch (e) {
      // Revert back cleanly on failure
      if (!_disposed) {
        state = AsyncData(current);
      }
      rethrow;
    } finally {
      _isMutating = false;
    }
  }

  Future<void> removeItem(String itemId) async {
    _isMutating = true;
    try {
      final repo = ref.read(channel6ScheduleRepositoryProvider);
      final updated = await repo.removeQueueItem(
        itemId,
        streamUrl: _resolveChannel6StreamUrl(),
      );
      if (!_disposed) {
        state = AsyncData(updated);
      }
    } finally {
      _isMutating = false;
    }
  }

  Future<void> clearQueue() async {
    _isMutating = true;
    try {
      final repo = ref.read(channel6ScheduleRepositoryProvider);
      final updated =
          await repo.clearQueue(streamUrl: _resolveChannel6StreamUrl());
      if (!_disposed) {
        state = AsyncData(updated);
      }
    } finally {
      _isMutating = false;
    }
  }

  Future<void> rescanLibrary() async {
    _isMutating = true;
    try {
      final repo = ref.read(channel6ScheduleRepositoryProvider);
      final updated =
          await repo.rescanLibrary(streamUrl: _resolveChannel6StreamUrl());
      if (!_disposed) {
        state = AsyncData(updated);
      }
    } finally {
      _isMutating = false;
    }
  }
}

