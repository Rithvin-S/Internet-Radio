import 'dart:async';
import 'package:flutter/foundation.dart';
import '../cache/cache_policy.dart';
import '../cache/cache_service.dart';
import 'sync_queue.dart';

/// Centralized state synchronization manager managing the offline mutation queue
class SyncService {
  final CacheService _cacheService;
  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier(SyncStatus.idle);
  bool _isProcessing = false;

  SyncService(this._cacheService);

  SyncStatus get status => statusNotifier.value;

  /// Retrieves the list of currently queued mutations
  List<SyncAction> getQueue() {
    try {
      final raw = _cacheService.getJson(CachePolicy.keySyncQueue, allowExpired: true);
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map((item) => SyncAction.fromJson(item))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Saves the pending action queue
  Future<void> _saveQueue(List<SyncAction> queue) async {
    final list = queue.map((a) => a.toJson()).toList();
    await _cacheService.setJson(CachePolicy.keySyncQueue, list);
  }

  /// Enqueues a new sync mutation with conflict reconciliation
  Future<void> enqueue(SyncAction action) async {
    final current = getQueue();

    // Reconcile opposite actions on the same station
    final existingIndex = current.indexWhere((a) => a.stationId == action.stationId);
    if (existingIndex >= 0) {
      final existing = current[existingIndex];
      if (existing.type != action.type) {
        // Opposite action cancels out earlier pending action
        current.removeAt(existingIndex);
        await _saveQueue(current);
        return;
      } else {
        // Same action already queued, ignore duplicate
        return;
      }
    }

    current.add(action);
    await _saveQueue(current);
    statusNotifier.value = SyncStatus.idle;
  }

  /// Removes an action from the queue by ID
  Future<void> dequeue(String id) async {
    final current = getQueue();
    current.removeWhere((a) => a.id == id);
    await _saveQueue(current);
  }

  /// Clears the entire queue
  Future<void> clearQueue() async {
    await _cacheService.remove(CachePolicy.keySyncQueue);
    statusNotifier.value = SyncStatus.idle;
  }

  /// Processes all pending items sequentially with retry limits and duplicate guards
  Future<bool> processQueue({
    required Future<bool> Function(SyncAction) onExecute,
  }) async {
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      final queue = getQueue();
      if (queue.isEmpty) {
        statusNotifier.value = SyncStatus.synced;
        return true;
      }

      statusNotifier.value = SyncStatus.syncing;
      final remaining = <SyncAction>[];
      bool anyFailure = false;

      for (final action in queue) {
        try {
          final success = await onExecute(action);
          if (!success) {
            final nextRetry = action.retryCount + 1;
            if (nextRetry < 3) {
              remaining.add(action.copyWith(retryCount: nextRetry));
            } else {
              // Exceeded max retries, discard to prevent infinite retry loops
              anyFailure = true;
            }
          }
        } catch (_) {
          final nextRetry = action.retryCount + 1;
          if (nextRetry < 3) {
            remaining.add(action.copyWith(retryCount: nextRetry));
          } else {
            anyFailure = true;
          }
        }
      }

      await _saveQueue(remaining);

      if (remaining.isEmpty) {
        statusNotifier.value = anyFailure ? SyncStatus.error : SyncStatus.synced;
      } else {
        statusNotifier.value = SyncStatus.error;
      }

      return remaining.isEmpty && !anyFailure;
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    statusNotifier.dispose();
  }
}

