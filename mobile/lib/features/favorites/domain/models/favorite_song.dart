import 'package:pulsecast/features/library/domain/models/listener_track.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';

/// Represents a favorited track with strict source separation
/// (General Radio Library vs Supabase Storage Music Library)
class FavoriteSong {
  final String id;
  final String source; // 'general' | 'supabase'
  final int? trackId; // Integer ID for General Library
  final String? songId; // UUID for Supabase Library
  final String title;
  final String artist;
  final String? album;
  final String? genre;
  final String? duration;
  final String? artworkUrl;
  final int? stationId;
  final String? stationName;
  final DateTime favoritedAt;

  const FavoriteSong({
    required this.id,
    required this.source,
    this.trackId,
    this.songId,
    required this.title,
    required this.artist,
    this.album,
    this.genre,
    this.duration,
    this.artworkUrl,
    this.stationId,
    this.stationName,
    required this.favoritedAt,
  });

  bool get isSupabase => source == 'supabase';
  bool get isGeneral => source == 'general';

  String get durationFormatted => duration ?? '--:--';

  factory FavoriteSong.fromListenerTrack(ListenerTrack track) {
    return FavoriteSong(
      id: 'general_${track.id}',
      source: 'general',
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      stationId: track.stationId,
      stationName: track.stationName,
      favoritedAt: DateTime.now(),
    );
  }

  factory FavoriteSong.fromAdminSong(AdminSong song) {
    return FavoriteSong(
      id: 'supabase_${song.id}',
      source: 'supabase',
      songId: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.formattedDuration,
      favoritedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'track_id': trackId,
      'song_id': songId,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'duration': duration,
      'artwork_url': artworkUrl,
      'station_id': stationId,
      'station_name': stationName,
      'favorited_at': favoritedAt.toIso8601String(),
    };
  }

  factory FavoriteSong.fromJson(Map<String, dynamic> json) {
    return FavoriteSong(
      id: json['id'] as String,
      source: json['source'] as String? ?? 'general',
      trackId: json['track_id'] as int?,
      songId: json['song_id'] as String?,
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String?,
      genre: json['genre'] as String?,
      duration: json['duration'] as String?,
      artworkUrl: json['artwork_url'] as String?,
      stationId: json['station_id'] as int?,
      stationName: json['station_name'] as String?,
      favoritedAt: DateTime.tryParse(json['favorited_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
