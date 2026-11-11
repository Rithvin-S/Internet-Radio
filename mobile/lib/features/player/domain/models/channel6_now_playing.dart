/// Currently playing track reported by Channel 6 Node.js `/api/now-playing`
class Channel6NowPlayingTrack {
  final String title;
  final String artist;

  const Channel6NowPlayingTrack({
    required this.title,
    required this.artist,
  });

  /// Parses `{ "currentTrack": { "title": "...", "artist": "..." } }` payloads.
  /// Returns `null` when `currentTrack` is absent/null or has no non-empty title.
  static Channel6NowPlayingTrack? tryFromJson(Map<String, dynamic> json) {
    final dynamic rawTrack = json['currentTrack'] ??
        (json['data'] is Map ? (json['data'] as Map)['currentTrack'] : null);
    if (rawTrack is! Map) return null;

    final trackMap = Map<String, dynamic>.from(rawTrack);
    final rawTitle = trackMap['title']?.toString().trim();
    if (rawTitle == null || rawTitle.isEmpty) return null;

    final rawArtist = trackMap['artist']?.toString().trim();
    return Channel6NowPlayingTrack(
      title: rawTitle,
      artist: (rawArtist != null && rawArtist.isNotEmpty)
          ? rawArtist
          : 'PulseCast Radio',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel6NowPlayingTrack &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          artist == other.artist;

  @override
  int get hashCode => title.hashCode ^ artist.hashCode;
}

/// UI state for Channel 6 live track metadata polling.
class Channel6NowPlayingState {
  final Channel6NowPlayingTrack? track;
  final bool isLoading;
  final bool hasLoadedOnce;
  final bool hasError;
  final int consecutiveErrors;
  final DateTime? lastUpdated;

  const Channel6NowPlayingState({
    this.track,
    this.isLoading = false,
    this.hasLoadedOnce = false,
    this.hasError = false,
    this.consecutiveErrors = 0,
    this.lastUpdated,
  });

  Channel6NowPlayingState copyWith({
    Channel6NowPlayingTrack? track,
    bool clearTrack = false,
    bool? isLoading,
    bool? hasLoadedOnce,
    bool? hasError,
    int? consecutiveErrors,
    DateTime? lastUpdated,
  }) {
    return Channel6NowPlayingState(
      track: clearTrack ? null : (track ?? this.track),
      isLoading: isLoading ?? this.isLoading,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      hasError: hasError ?? this.hasError,
      consecutiveErrors: consecutiveErrors ?? this.consecutiveErrors,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Channel6NowPlayingState &&
          runtimeType == other.runtimeType &&
          track == other.track &&
          isLoading == other.isLoading &&
          hasLoadedOnce == other.hasLoadedOnce &&
          hasError == other.hasError &&
          consecutiveErrors == other.consecutiveErrors &&
          lastUpdated == other.lastUpdated;

  @override
  int get hashCode =>
      track.hashCode ^
      isLoading.hashCode ^
      hasLoadedOnce.hashCode ^
      hasError.hashCode ^
      consecutiveErrors.hashCode ^
      lastUpdated.hashCode;
}

