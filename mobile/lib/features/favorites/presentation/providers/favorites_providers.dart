import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/cache/cache_providers.dart';
import 'package:pulsecast/core/connectivity/connectivity_providers.dart';
import 'package:pulsecast/core/connectivity/connectivity_service.dart';
import 'package:pulsecast/core/network/network_providers.dart';
import 'package:pulsecast/core/sync/sync_providers.dart';
import 'package:pulsecast/core/sync/sync_queue.dart';
import 'package:pulsecast/features/auth/presentation/providers/auth_providers.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import '../../data/favorites_repository.dart';
import '../../domain/models/favorite_song.dart';

class FavoritesState {
  final Set<int> favoriteStationIds;
  final List<Station> favoriteStations;
  final List<FavoriteSong> favoriteSongs;
  final bool isLoading;
  final String? error;

  const FavoritesState({
    this.favoriteStationIds = const {},
    this.favoriteStations = const [],
    this.favoriteSongs = const [],
    this.isLoading = false,
    this.error,
  });

  FavoritesState copyWith({
    Set<int>? favoriteStationIds,
    List<Station>? favoriteStations,
    List<FavoriteSong>? favoriteSongs,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FavoritesState(
      favoriteStationIds: favoriteStationIds ?? this.favoriteStationIds,
      favoriteStations: favoriteStations ?? this.favoriteStations,
      favoriteSongs: favoriteSongs ?? this.favoriteSongs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Provider for the FavoritesRepository
final favoritesRepositoryProvider = Provider<IFavoritesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return FavoritesRepository(
    apiClient: apiClient,
    cacheService: cacheService,
  );
});

/// Reactive Notifier managing favorite stations and songs with offline queue synchronization
class FavoritesNotifier extends Notifier<FavoritesState> {
  late final IFavoritesRepository _repository;
  String? _currentUserId;

  @override
  FavoritesState build() {
    _repository = ref.watch(favoritesRepositoryProvider);

    // Track authenticated user changes
    ref.listen(authNotifierProvider, (previous, next) {
      final nextUserId = next.user?.id.toString();
      if (_currentUserId != nextUserId) {
        final wasGuest = _currentUserId == null;
        _currentUserId = nextUserId;

        if (wasGuest && nextUserId != null) {
          // Guest just logged in — trigger explicit guest-to-user merge!
          mergeGuestFavorites(nextUserId);
        } else {
          loadFavorites();
        }
      }
    });

    // Listen to network connectivity restoration to trigger queue synchronization
    ref.listen(connectivityStatusProvider, (previous, next) {
      if ((previous == ConnectivityStatus.offline ||
              previous == ConnectivityStatus.serverUnavailable) &&
          next == ConnectivityStatus.online) {
        syncPendingQueue();
      }
    });

    // Initialize with current user ID if already authenticated
    final authState = ref.read(authNotifierProvider);
    _currentUserId = authState.user?.id.toString();

    // Load initial favorites from local storage & server
    Future.microtask(() => loadFavorites());

    return const FavoritesState(isLoading: true);
  }

  /// Loads favorite stations and songs for the current user/guest
  Future<void> loadFavorites() async {
    final isOnline = ref.read(isOnlineProvider);
    final localStationIds = _repository.getLocalFavoriteStationIds(userId: _currentUserId);
    final songs = _repository.getFavoriteSongs(userId: _currentUserId);

    state = state.copyWith(
      favoriteStationIds: localStationIds,
      favoriteSongs: songs,
      isLoading: true,
      clearError: true,
    );

    try {
      final stations = await _repository.getFavoriteStations(
        userId: _currentUserId,
        isOnline: isOnline,
      );

      final updatedIds = stations.map((s) => s.id).toSet();
      state = state.copyWith(
        favoriteStationIds: updatedIds.isEmpty ? localStationIds : updatedIds,
        favoriteStations: stations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to refresh favorites: $e',
      );
    }
  }

  /// Toggles a radio station's favorite state with immediate UI update & sync queue
  Future<void> toggleFavoriteStation(Station station) async {
    HapticFeedback.lightImpact();
    final isFav = state.favoriteStationIds.contains(station.id);
    final isOnline = ref.read(isOnlineProvider);
    final syncService = ref.read(syncServiceProvider);

    // 1. Instant 0ms Optimistic UI update
    final newIds = Set<int>.from(state.favoriteStationIds);
    final newStations = List<Station>.from(state.favoriteStations);

    if (isFav) {
      newIds.remove(station.id);
      newStations.removeWhere((s) => s.id == station.id);
    } else {
      newIds.add(station.id);
      if (!newStations.any((s) => s.id == station.id)) {
        newStations.add(station);
      }
    }

    state = state.copyWith(
      favoriteStationIds: newIds,
      favoriteStations: newStations,
    );

    // 2. Persist locally & sync to server
    if (isFav) {
      final synced = await _repository.removeFavoriteStation(
        station.id,
        userId: _currentUserId,
        isOnline: isOnline,
      );
      if (!synced && _currentUserId != null) {
        // Enqueue offline action for later synchronization
        await syncService.enqueue(
          SyncAction(
            id: 'rm_${station.id}_${DateTime.now().millisecondsSinceEpoch}',
            type: SyncActionType.removeFavoriteStation,
            stationId: station.id,
            createdAt: DateTime.now(),
          ),
        );
      }
    } else {
      final synced = await _repository.addFavoriteStation(
        station,
        userId: _currentUserId,
        isOnline: isOnline,
      );
      if (!synced && _currentUserId != null) {
        // Enqueue offline action for later synchronization
        await syncService.enqueue(
          SyncAction(
            id: 'add_${station.id}_${DateTime.now().millisecondsSinceEpoch}',
            type: SyncActionType.addFavoriteStation,
            stationId: station.id,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  /// Toggles a song's favorite state (stored locally, strictly scoped by user)
  Future<void> toggleFavoriteSong(FavoriteSong song) async {
    HapticFeedback.lightImpact();
    final currentSongs = List<FavoriteSong>.from(state.favoriteSongs);
    final exists = currentSongs.any((s) => s.id == song.id);

    if (exists) {
      currentSongs.removeWhere((s) => s.id == song.id);
      await _repository.removeFavoriteSong(song.id, userId: _currentUserId);
    } else {
      currentSongs.insert(0, song);
      await _repository.addFavoriteSong(song, userId: _currentUserId);
    }

    state = state.copyWith(favoriteSongs: currentSongs);
  }

  /// Checks if a song is favorited
  bool isSongFavorited(String favoriteId) {
    return state.favoriteSongs.any((s) => s.id == favoriteId);
  }

  /// Merges guest favorites into the authenticated account
  Future<void> mergeGuestFavorites(String userId) async {
    final isOnline = ref.read(isOnlineProvider);
    state = state.copyWith(isLoading: true);

    try {
      final newlyMerged = await _repository.mergeGuestFavorites(
        userId: userId,
        isOnline: isOnline,
      );

      // If offline, enqueue the newly merged station IDs
      if (!isOnline && newlyMerged.isNotEmpty) {
        final syncService = ref.read(syncServiceProvider);
        for (final id in newlyMerged) {
          await syncService.enqueue(
            SyncAction(
              id: 'merge_${id}_${DateTime.now().millisecondsSinceEpoch}',
              type: SyncActionType.addFavoriteStation,
              stationId: id,
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      await loadFavorites();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Processes any deferred offline actions against the backend
  Future<void> syncPendingQueue() async {
    if (_currentUserId == null) return;
    final syncService = ref.read(syncServiceProvider);

    await syncService.processQueue(
      onExecute: (action) async {
        if (action.type == SyncActionType.addFavoriteStation) {
          // Use temporary placeholder or existing station
          final station = state.favoriteStations.firstWhere(
            (s) => s.id == action.stationId,
            orElse: () => Station(
              id: action.stationId,
              name: 'Station #${action.stationId}',
              streamUrl: '',
              isActive: true,
            ),
          );
          return await _repository.addFavoriteStation(
            station,
            userId: _currentUserId,
            isOnline: true,
          );
        } else {
          return await _repository.removeFavoriteStation(
            action.stationId,
            userId: _currentUserId,
            isOnline: true,
          );
        }
      },
    );

    // Refresh after synchronization
    await loadFavorites();
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);

/// Family provider returning whether a specific station ID is favorited
final isStationFavoriteProvider = Provider.family<bool, int>((ref, stationId) {
  final favState = ref.watch(favoritesProvider);
  return favState.favoriteStationIds.contains(stationId);
});

/// Family provider returning whether a specific song ID is favorited
final isSongFavoriteProvider = Provider.family<bool, String>((ref, songId) {
  final favState = ref.watch(favoritesProvider);
  return favState.favoriteSongs.any((s) => s.id == songId);
});

