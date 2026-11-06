import 'schedule_playlist_track.dart';

class AdminSchedule {
  final int id;
  final int stationId;
  final String? stationName;
  final String? stationGenre;
  final String title;
  final String? description;
  final String? category;
  final String scheduleDate;
  final String startTime;
  final String endTime;
  final bool isPublished;
  final bool isRecurring;
  final String status;
  final int songCount;
  final List<SchedulePlaylistTrack> songs;
  final DateTime? createdAt;

  const AdminSchedule({
    required this.id,
    required this.stationId,
    this.stationName,
    this.stationGenre,
    required this.title,
    this.description,
    this.category,
    required this.scheduleDate,
    required this.startTime,
    required this.endTime,
    this.isPublished = false,
    this.isRecurring = false,
    this.status = 'draft',
    this.songCount = 0,
    this.songs = const [],
    this.createdAt,
  });

  bool get isLiveOrActive => isPublished;

  String get timeRange => '$startTime - $endTime';

  factory AdminSchedule.fromJson(Map<String, dynamic> json) {
    List<SchedulePlaylistTrack> parsedSongs = [];
    if (json['songs'] is List) {
      parsedSongs = (json['songs'] as List)
          .whereType<Map<String, dynamic>>()
          .map((song) => SchedulePlaylistTrack.fromJson(song))
          .toList();
    }

    final published = json['is_published'] is bool
        ? json['is_published'] as bool
        : (json['is_published'] == 1 || json['status'] == 'published');

    return AdminSchedule(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      stationId: json['station_id'] is int
          ? json['station_id'] as int
          : (int.tryParse(json['station_id']?.toString() ?? '') ?? 0),
      stationName: json['station_name'] as String?,
      stationGenre: json['station_genre'] as String?,
      title: json['title'] as String? ?? 'Untitled Broadcast',
      description: json['description'] as String?,
      category: json['category'] as String?,
      scheduleDate: json['schedule_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '00:00',
      endTime: json['end_time'] as String? ?? '00:00',
      isPublished: published,
      isRecurring: json['is_recurring'] as bool? ?? false,
      status: json['status'] as String? ?? (published ? 'published' : 'draft'),
      songCount: json['song_count'] is int
          ? json['song_count'] as int
          : (json['total_songs'] is int
              ? json['total_songs'] as int
              : parsedSongs.length),
      songs: parsedSongs,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'station_name': stationName,
      'station_genre': stationGenre,
      'title': title,
      'description': description,
      'category': category,
      'schedule_date': scheduleDate,
      'start_time': startTime,
      'end_time': endTime,
      'is_published': isPublished,
      'is_recurring': isRecurring,
      'status': status,
      'song_count': songCount,
      'songs': songs.map((s) => s.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  AdminSchedule copyWith({
    int? id,
    int? stationId,
    String? stationName,
    String? stationGenre,
    String? title,
    String? description,
    String? category,
    String? scheduleDate,
    String? startTime,
    String? endTime,
    bool? isPublished,
    bool? isRecurring,
    String? status,
    int? songCount,
    List<SchedulePlaylistTrack>? songs,
    DateTime? createdAt,
  }) {
    return AdminSchedule(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      stationGenre: stationGenre ?? this.stationGenre,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      scheduleDate: scheduleDate ?? this.scheduleDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isPublished: isPublished ?? this.isPublished,
      isRecurring: isRecurring ?? this.isRecurring,
      status: status ?? this.status,
      songCount: songCount ?? this.songCount,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
