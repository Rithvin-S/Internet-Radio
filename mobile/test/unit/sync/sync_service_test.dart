import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsecast/core/cache/cache_service.dart';
import 'package:pulsecast/core/sync/sync_queue.dart';
import 'package:pulsecast/core/sync/sync_service.dart';

void main() {
  group('SyncService & Queue Unit Tests', () {
    late SharedPreferences prefs;
    late CacheService cacheService;
    late SyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      cacheService = CacheService(prefs);
      syncService = SyncService(cacheService);
    });

    test('enqueue adds action and ignores duplicate', () async {
      final action1 = SyncAction(
        id: 'act_1',
        type: SyncActionType.addFavoriteStation,
        stationId: 5,
        createdAt: DateTime.now(),
      );

      await syncService.enqueue(action1);
      expect(syncService.getQueue().length, equals(1));

      // Re-enqueue exact same action
      await syncService.enqueue(action1);
      expect(syncService.getQueue().length, equals(1));
    });

    test('Opposite action on the same station reconciles and cancels out', () async {
      final addAction = SyncAction(
        id: 'act_add',
        type: SyncActionType.addFavoriteStation,
        stationId: 5,
        createdAt: DateTime.now(),
      );
      await syncService.enqueue(addAction);
      expect(syncService.getQueue().length, equals(1));

      // Enqueue opposite action: remove station 5
      final removeAction = SyncAction(
        id: 'act_rm',
        type: SyncActionType.removeFavoriteStation,
        stationId: 5,
        createdAt: DateTime.now(),
      );
      await syncService.enqueue(removeAction);

      // Both should cancel out!
      expect(syncService.getQueue(), isEmpty);
    });

    test('processQueue executes pending actions and clears queue on success', () async {
      await syncService.enqueue(
        SyncAction(
          id: 'act_1',
          type: SyncActionType.addFavoriteStation,
          stationId: 1,
          createdAt: DateTime.now(),
        ),
      );
      await syncService.enqueue(
        SyncAction(
          id: 'act_2',
          type: SyncActionType.addFavoriteStation,
          stationId: 2,
          createdAt: DateTime.now(),
        ),
      );

      final executedStationIds = <int>[];
      final ok = await syncService.processQueue(
        onExecute: (action) async {
          executedStationIds.add(action.stationId);
          return true;
        },
      );

      expect(ok, isTrue);
      expect(executedStationIds, equals([1, 2]));
      expect(syncService.getQueue(), isEmpty);
      expect(syncService.status, equals(SyncStatus.synced));
    });

    test('processQueue increments retry count on failure and drops after 3 retries', () async {
      await syncService.enqueue(
        SyncAction(
          id: 'act_fail',
          type: SyncActionType.addFavoriteStation,
          stationId: 99,
          createdAt: DateTime.now(),
        ),
      );

      // Attempt 1: fail
      await syncService.processQueue(onExecute: (_) async => false);
      expect(syncService.getQueue().first.retryCount, equals(1));

      // Attempt 2: fail
      await syncService.processQueue(onExecute: (_) async => false);
      expect(syncService.getQueue().first.retryCount, equals(2));

      // Attempt 3: fail -> dropped to prevent infinite loops
      await syncService.processQueue(onExecute: (_) async => false);
      expect(syncService.getQueue(), isEmpty);
      expect(syncService.status, equals(SyncStatus.error));
    });
  });
}

