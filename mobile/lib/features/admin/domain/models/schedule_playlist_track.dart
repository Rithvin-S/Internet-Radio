class SchedulePlaylistTrack {
  final String? id;
  final int? scheduleId;
  final String? songId; // UUID for Supabase Storage library
  final int? trackId; // Integer ID for General Library
  final String source; // 'supabase' | 'general'
  final String title;
  final String artist;
  final String? album;
  final String? duration;
  final int durationSeconds;
  final String? streamUrl;
  final int playOrder;
  final DateTime? createdAt;

  const SchedulePlaylistTrack({
    this.id,
    this.scheduleId,
    this.songId,
    this.trackId,
    required this.source,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.durationSeconds = 0,
    this.streamUrl,
    this.playOrder = 0,
    this.createdAt,
  });

  bool get isSupabase => source.toLowerCase() == 'supabase';
  bool get isGeneral => source.toLowerCase() == 'general';

  String get formattedDuration {
    if (duration != null && duration!.isNotEmpty) return duration!;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory SchedulePlaylistTrack.fromJson(Map<String, dynamic> json) {
    return SchedulePlaylistTrack(
      id: json['id']?.toString(),
      scheduleId: json['schedule_id'] is int
          ? json['schedule_id'] as int
          : int.tryParse(json['schedule_id']?.toString() ?? ''),
      songId: json['song_id']?.toString(),
      trackId: json['track_id'] is int
          ? json['track_id'] as int
          : int.tryParse(json['track_id']?.toString() ?? ''),
      source: (json['source'] as String? ?? 'general').toLowerCase(),
      title: json['title'] as String? ?? 'Untitled Track',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String?,
      duration: json['duration'] as String?,
      durationSeconds: json['duration_seconds'] is int
          ? json['duration_seconds'] as int
          : (int.tryParse(json['duration_seconds']?.toString() ?? '') ?? 0),
      streamUrl: json['stream_url'] as String?,
      playOrder: json['play_order'] is int
          ? json['play_order'] as int
          : (int.tryParse(json['play_order']?.toString() ?? '') ?? 0),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (songId != null) 'song_id': songId,
      if (trackId != null) 'track_id': trackId,
      'source': source,
      'title': title,
      'artist': artist,
      if (album != null) 'album': album,
      if (duration != null) 'duration': duration,
      'duration_seconds': durationSeconds,
      if (streamUrl != null) 'stream_url': streamUrl,
      'play_order': playOrder,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Format for PUT /api/admin/schedules/:id/tracks batch request
  Map<String, dynamic> toBatchJson() {
    return {
      'id': songId ?? trackId?.toString() ?? id ?? '',
      if (songId != null) 'song_id': songId,
      if (trackId != null) 'track_id': trackId,
      'source': source,
      'title': title,
      'artist': artist,
      if (album != null) 'album': album,
      if (duration != null) 'duration': duration,
      'duration_seconds': durationSeconds,
      'play_order': playOrder,
    };
  }
}
