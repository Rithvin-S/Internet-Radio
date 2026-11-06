import 'package:pulsecast/features/stations/domain/models/station.dart';
import 'package:pulsecast/features/player/domain/models/now_playing_info.dart';

enum RadioPlaybackStatus {
  idle,
  loading,
  buffering,
  playing,
  paused,
  reconnecting,
  error,
}

/// Reactive immutable state representing current radio playback
class PlayerState {
  final Station? currentStation;
  final RadioPlaybackStatus status;
  final String? errorMessage;
  final NowPlayingInfo? nowPlaying;

  const PlayerState({
    this.currentStation,
    this.status = RadioPlaybackStatus.idle,
    this.errorMessage,
    this.nowPlaying,
  });

  bool get isPlaying => status == RadioPlaybackStatus.playing;
  bool get isLoading => status == RadioPlaybackStatus.loading;
  bool get isBuffering => status == RadioPlaybackStatus.buffering;
  bool get isReconnecting => status == RadioPlaybackStatus.reconnecting;
  bool get isPaused => status == RadioPlaybackStatus.paused;
  bool get isIdle => status == RadioPlaybackStatus.idle;
  bool get hasError => status == RadioPlaybackStatus.error;
  bool get hasActiveStation => currentStation != null;

  PlayerState copyWith({
    Station? currentStation,
    RadioPlaybackStatus? status,
    String? errorMessage,
    NowPlayingInfo? nowPlaying,
    bool clearStation = false,
    bool clearError = false,
  }) {
    return PlayerState(
      currentStation: clearStation ? null : (currentStation ?? this.currentStation),
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      nowPlaying: nowPlaying ?? this.nowPlaying,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerState &&
          runtimeType == other.runtimeType &&
          currentStation == other.currentStation &&
          status == other.status &&
          errorMessage == other.errorMessage &&
          nowPlaying == other.nowPlaying;

  @override
  int get hashCode =>
      currentStation.hashCode ^
      status.hashCode ^
      errorMessage.hashCode ^
      nowPlaying.hashCode;
}
