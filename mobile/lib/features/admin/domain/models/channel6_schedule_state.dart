/// Local music folder track indexed by the Channel 6 Node.js streamer
class Channel6LibraryTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final double durationSeconds;
  final String durationFormatted;
  final int bitrateKbps;
  final int fileSize;

  const Channel6LibraryTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    required this.durationFormatted,
    required this.bitrateKbps,
    required this.fileSize,
  });

  factory Channel6LibraryTrack.fromJson(Map<String, dynamic> json) {
    return Channel6LibraryTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: json['artist']?.toString() ?? 'PulseCast Artist',
      album: json['album']?.toString() ?? 'PulseCast Music Library',
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      durationFormatted: json['durationFormatted']?.toString() ?? '00:00',
      bitrateKbps: (json['bitrateKbps'] as num?)?.toInt() ?? 192,
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Ordered entry inside Channel 6's admin playback queue
class Channel6QueueItem {
  final String itemId;
  final String trackId;
  final int position;
  final String title;
  final String artist;
  final String album;
  final double durationSeconds;
  final String durationFormatted;
  final bool available;
  final String? addedAt;

  const Channel6QueueItem({
    required this.itemId,
    required this.trackId,
    required this.position,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    required this.durationFormatted,
    this.available = true,
    this.addedAt,
  });

  Channel6QueueItem copyWith({int? position}) {
    return Channel6QueueItem(
      itemId: itemId,
      trackId: trackId,
      position: position ?? this.position,
      title: title,
      artist: artist,
      album: album,
      durationSeconds: durationSeconds,
      durationFormatted: durationFormatted,
      available: available,
      addedAt: addedAt,
    );
  }

  factory Channel6QueueItem.fromJson(Map<String, dynamic> json) {
    return Channel6QueueItem(
      itemId: json['itemId']?.toString() ?? '',
      trackId: json['trackId']?.toString() ?? '',
      position: (json['position'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? 'Unknown Track',
      artist: json['artist']?.toString() ?? 'PulseCast Artist',
      album: json['album']?.toString() ?? 'PulseCast Music Library',
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      durationFormatted: json['durationFormatted']?.toString() ?? '00:00',
      available: json['available'] as bool? ?? true,
      addedAt: json['addedAt']?.toString(),
    );
  }
}

/// Track currently playing or queued next on the Channel 6 timeline
class Channel6ScheduledTrackInfo {
  final String id;
  final String title;
  final String artist;
  final String album;
  final double durationSeconds;
  final String durationFormatted;
  final String source; // 'admin_schedule' | 'fallback_shuffle' | 'custom_playlist'

  const Channel6ScheduledTrackInfo({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    required this.durationFormatted,
    required this.source,
  });

  bool get isAdminScheduled => source == 'admin_schedule';

  String get sourceLabel =>
      isAdminScheduled ? 'Up Next Queue' : 'Shuffle Fallback';

  factory Channel6ScheduledTrackInfo.fromJson(Map<String, dynamic> json) {
    return Channel6ScheduledTrackInfo(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Title',
      artist: json['artist']?.toString() ?? 'PulseCast Artist',
      album: json['album']?.toString() ?? 'PulseCast Music Library',
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      durationFormatted: json['durationFormatted']?.toString() ?? '00:00',
      source: json['source']?.toString() ?? 'fallback_shuffle',
    );
  }
}

/// Full Channel 6 admin scheduling snapshot (active mode, now playing, queue, and local library)
class Channel6ScheduleState {
  final String playbackMode; // 'admin_schedule' | 'fallback'
  final String playbackModeLabel;
  final String currentTrackSource; // 'admin_schedule' | 'fallback_shuffle'
  final bool isScheduleQueuedNext;
  final Channel6ScheduledTrackInfo? currentTrack;
  final double elapsedSeconds;
  final double remainingSeconds;
  final Channel6ScheduledTrackInfo? nextTrack;
  final List<Channel6QueueItem> queue;
  final List<Channel6LibraryTrack> library;

  const Channel6ScheduleState({
    required this.playbackMode,
    required this.playbackModeLabel,
    required this.currentTrackSource,
    required this.isScheduleQueuedNext,
    this.currentTrack,
    this.elapsedSeconds = 0.0,
    this.remainingSeconds = 0.0,
    this.nextTrack,
    this.queue = const [],
    this.library = const [],
  });

  bool get isAdminScheduleMode => playbackMode == 'admin_schedule';
  bool get isCurrentFromAdminSchedule => currentTrackSource == 'admin_schedule';

  Channel6ScheduleState copyWith({
    String? playbackMode,
    String? playbackModeLabel,
    String? currentTrackSource,
    bool? isScheduleQueuedNext,
    List<Channel6QueueItem>? queue,
  }) {
    return Channel6ScheduleState(
      playbackMode: playbackMode ?? this.playbackMode,
      playbackModeLabel: playbackModeLabel ?? this.playbackModeLabel,
      currentTrackSource: currentTrackSource ?? this.currentTrackSource,
      isScheduleQueuedNext: isScheduleQueuedNext ?? this.isScheduleQueuedNext,
      currentTrack: currentTrack,
      elapsedSeconds: elapsedSeconds,
      remainingSeconds: remainingSeconds,
      nextTrack: nextTrack,
      queue: queue ?? this.queue,
      library: library,
    );
  }

  factory Channel6ScheduleState.fromJson(Map<String, dynamic> json) {
    final currentMap = json['currentTrack'];
    final nextMap = json['nextTrack'];
    final rawQueue = json['queue'] as List<dynamic>? ?? const [];
    final rawLibrary = json['library'] as List<dynamic>? ?? const [];

    return Channel6ScheduleState(
      playbackMode: json['playbackMode']?.toString() ?? 'fallback',
      playbackModeLabel:
          json['playbackModeLabel']?.toString() ?? 'Shuffle Fallback',
      currentTrackSource:
          json['currentTrackSource']?.toString() ?? 'fallback_shuffle',
      isScheduleQueuedNext: json['isScheduleQueuedNext'] as bool? ?? false,
      currentTrack: currentMap is Map
          ? Channel6ScheduledTrackInfo.fromJson(
              Map<String, dynamic>.from(currentMap),
            )
          : null,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toDouble() ?? 0.0,
      remainingSeconds: (json['remainingSeconds'] as num?)?.toDouble() ?? 0.0,
      nextTrack: nextMap is Map
          ? Channel6ScheduledTrackInfo.fromJson(
              Map<String, dynamic>.from(nextMap),
            )
          : null,
      queue: rawQueue
          .whereType<Map>()
          .map((e) => Channel6QueueItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      library: rawLibrary
          .whereType<Map>()
          .map(
            (e) => Channel6LibraryTrack.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

