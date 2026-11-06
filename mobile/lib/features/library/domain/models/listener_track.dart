class ListenerTrack {
  final int id;
  final int stationId;
  final String stationName;
  final String title;
  final String artist;
  final String? album;
  final String? duration;
  final String? streamUrl;
  final int playOrder;
  final String status;
  final DateTime? createdAt;

  const ListenerTrack({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.streamUrl,
    this.playOrder = 0,
    this.status = 'queued',
    this.createdAt,
  });

  bool get isCurrentlyPlaying => status.toLowerCase() == 'playing';
  bool get isQueued => status.toLowerCase() == 'queued';

  factory ListenerTrack.fromJson(
    Map<String, dynamic> json, {
    int defaultStationId = 0,
    String defaultStationName = 'Unknown Station',
  }) {
    DateTime? parsedDate;
    if (json['created_at'] != null) {
      parsedDate = DateTime.tryParse(json['created_at'].toString());
    }

    return ListenerTrack(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      stationId: json['station_id'] is int
          ? json['station_id'] as int
          : (int.tryParse(json['station_id']?.toString() ?? '') ?? defaultStationId),
      stationName: json['station_name'] as String? ?? defaultStationName,
      title: json['title'] as String? ?? 'Untitled Track',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String?,
      duration: json['duration'] as String?,
      streamUrl: json['stream_url'] as String?,
      playOrder: json['play_order'] is int ? json['play_order'] as int : 0,
      status: json['status'] as String? ?? 'queued',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'station_name': stationName,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'stream_url': streamUrl,
      'play_order': playOrder,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
