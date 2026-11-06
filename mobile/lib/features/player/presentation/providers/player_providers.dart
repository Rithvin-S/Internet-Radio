import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulsecast/core/network/network_providers.dart';
import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/player/data/now_playing_repository.dart';
import 'package:pulsecast/features/player/domain/models/now_playing_info.dart';
import 'package:pulsecast/features/player/services/radio_audio_handler.dart';
import 'player_notifier.dart';
import 'player_state.dart';

/// Configurable interval for periodic metadata polling (null disables periodic timer)
final metadataPollingIntervalProvider =
    Provider<Duration?>((ref) => const Duration(seconds: 20));

/// Provider holding the singleton persistent RadioAudioHandler
final radioAudioHandlerProvider = Provider<RadioAudioHandler>((ref) {
  // Overridden at runtime in main.dart with the initialized AudioService instance
  return RadioAudioHandler();
});

/// Provider for NowPlayingRepository
final nowPlayingRepositoryProvider = Provider<INowPlayingRepository>((ref) {
  return NowPlayingRepository(apiClient: ref.watch(apiClientProvider));
});

/// Central Riverpod NotifierProvider for radio playback state
final playerNotifierProvider =
    NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);

/// Selector for the currently active/selected station
final currentStationProvider = Provider<Station?>((ref) {
  return ref.watch(playerNotifierProvider).currentStation;
});

/// Selector for playback status
final playbackStatusProvider = Provider<RadioPlaybackStatus>((ref) {
  return ref.watch(playerNotifierProvider).status;
});

/// Selector checking if stream is actively playing
final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playerNotifierProvider).isPlaying;
});

/// Selector checking if player is currently loading or buffering
final isAudioLoadingProvider = Provider<bool>((ref) {
  return ref.watch(playerNotifierProvider).isLoading;
});

/// Selector for current broadcast & track metadata
final nowPlayingInfoProvider = Provider<NowPlayingInfo?>((ref) {
  return ref.watch(playerNotifierProvider).nowPlaying;
});
