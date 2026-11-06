/// Queued track item from station tracks playlist
class QueuedTrack {
  final dynamic id;
  final String title;
  final String? artist;
  final String? album;
  final String? duration;
  final String? artworkUrl;

  const QueuedTrack({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.artworkUrl,
  });

  factory QueuedTrack.fromJson(Map<String, dynamic> json) {
    return QueuedTrack(
      id: json['id'],
      title: json['title'] as String? ?? 'Upcoming Track',
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      duration: json['duration'] as String?,
      artworkUrl: json['artwork_url'] as String?,
    );
  }
}

/// Metadata representing the active broadcast program and now-playing track
class NowPlayingInfo {
  final int stationId;
  final String? stationName;
  final String? title;
  final String? artist;
  final String? album;
  final String? duration;
  final String? artworkUrl;
  final String? programTitle;
  final String? startTime;
  final String? endTime;
  final List<QueuedTrack> upNext;

  const NowPlayingInfo({
    required this.stationId,
    this.stationName,
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.artworkUrl,
    this.programTitle,
    this.startTime,
    this.endTime,
    this.upNext = const [],
  });

  bool get hasTrackMetadata =>
      (title != null && title!.isNotEmpty) || (artist != null && artist!.isNotEmpty);

  bool get hasProgramMetadata =>
      programTitle != null && programTitle!.isNotEmpty;

  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : (programTitle ?? 'Live Broadcast');

  String get displaySubtitle =>
      (artist != null && artist!.isNotEmpty) ? artist! : (stationName ?? 'PulseCast Live');

  factory NowPlayingInfo.fromTracksJson(int stationId, Map<String, dynamic> json) {
    final nowPlayingMap = json['now_playing'] as Map<String, dynamic>?;
    final upNextList = json['up_next'] as List<dynamic>? ?? [];
    final stationMap = json['station'] as Map<String, dynamic>?;

    return NowPlayingInfo(
      stationId: stationId,
      stationName: stationMap?['name'] as String?,
      title: nowPlayingMap?['title'] as String?,
      artist: nowPlayingMap?['artist'] as String?,
      album: nowPlayingMap?['album'] as String?,
      duration: nowPlayingMap?['duration'] as String?,
      artworkUrl: nowPlayingMap?['artwork_url'] as String?,
      upNext: upNextList
          .whereType<Map<String, dynamic>>()
          .map((t) => QueuedTrack.fromJson(t))
          .toList(),
    );
  }

  factory NowPlayingInfo.fromBroadcastJson(int stationId, Map<String, dynamic> json) {
    final scheduleMap = json['schedule'] as Map<String, dynamic>?;

    return NowPlayingInfo(
      stationId: stationId,
      programTitle: scheduleMap?['title'] as String?,
      startTime: scheduleMap?['start_time'] as String?,
      endTime: scheduleMap?['end_time'] as String?,
    );
  }

  NowPlayingInfo merge(NowPlayingInfo other) {
    return NowPlayingInfo(
      stationId: stationId,
      stationName: other.stationName ?? stationName,
      title: other.title ?? title,
      artist: other.artist ?? artist,
      album: other.album ?? album,
      duration: other.duration ?? duration,
      artworkUrl: other.artworkUrl ?? artworkUrl,
      programTitle: other.programTitle ?? programTitle,
      startTime: other.startTime ?? startTime,
      endTime: other.endTime ?? endTime,
      upNext: other.upNext.isNotEmpty ? other.upNext : upNext,
    );
  }
}

