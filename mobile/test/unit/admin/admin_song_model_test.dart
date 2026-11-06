import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/features/admin/domain/models/admin_schedule.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song_stats.dart';
import 'package:pulsecast/features/admin/domain/models/schedule_playlist_track.dart';
import 'package:pulsecast/features/admin/domain/models/song_signed_url.dart';

void main() {
  group('Admin Song & Stats Domain Models Tests', () {
    test('AdminSong parses Supabase Storage fields and formats duration/size', () {
      final json = {
        'id': '1a3825f2-1b65-4615-9f03-c42722d73551',
        'title': 'Teardrop',
        'artist': 'Massive Attack',
        'album': 'Mezzanine',
        'duration': '05:30',
        'duration_seconds': 330,
        'mime_type': 'audio/mpeg',
        'file_size_bytes': 7890123,
        'file_hash': '5ffb16cb0285a508d4a5e80fc0c88e10f328b3f28a9a4c77178790b87767126c',
        'storage_bucket': 'pulsecast-music-library',
        'storage_path': 'library/1a3825f2-.../teardrop.mp3',
        'original_filename': 'teardrop.mp3',
        'is_active': true,
      };

      final song = AdminSong.fromJson(json);

      expect(song.id, '1a3825f2-1b65-4615-9f03-c42722d73551');
      expect(song.title, 'Teardrop');
      expect(song.artist, 'Massive Attack');
      expect(song.durationSeconds, 330);
      expect(song.storageBucket, 'pulsecast-music-library');
      expect(song.isActive, isTrue);
      expect(song.formattedDuration, '05:30');
      expect(song.formattedFileSize, contains('MB'));
    });

    test('AdminSongStats formats storage bytes and total duration correctly', () {
      final json = {
        'totalSongs': 10,
        'activeSongs': 9,
        'totalStorageBytes': 104857600, // 100 MB
        'totalDurationSeconds': 3720, // 1h 2m
      };

      final stats = AdminSongStats.fromJson(json);

      expect(stats.totalSongs, 10);
      expect(stats.activeSongs, 9);
      expect(stats.formattedTotalStorage, '100.0 MB');
      expect(stats.formattedTotalDuration, '1h 2m');
    });

    test('SongSignedUrl tracks expiration calculation correctly', () {
      final validUrl = SongSignedUrl(
        songId: '1a3825f2-1b65-4615-9f03-c42722d73551',
        title: 'Teardrop',
        artist: 'Massive Attack',
        signedUrl: 'https://supabase.co/storage/v1/object/sign/...',
        expiresIn: 300,
        createdAt: DateTime.now(),
      );

      expect(validUrl.isExpired, isFalse);

      final expiredUrl = SongSignedUrl(
        songId: '1a3825f2-1b65-4615-9f03-c42722d73551',
        title: 'Teardrop',
        artist: 'Massive Attack',
        signedUrl: 'https://supabase.co/storage/v1/object/sign/...',
        expiresIn: 60,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      expect(expiredUrl.isExpired, isTrue);
    });

    test('SchedulePlaylistTrack maintains General vs Supabase isolation without ID collision', () {
      // 1. Supabase Track (UUID song_id)
      final supabaseJson = {
        'id': 'c13d7890-uuid',
        'schedule_id': 1,
        'song_id': '1a3825f2-1b65-4615-9f03-c42722d73551',
        'track_id': null,
        'source': 'supabase',
        'title': 'Teardrop',
        'artist': 'Massive Attack',
        'duration_seconds': 330,
        'play_order': 1,
      };

      final supabaseTrack = SchedulePlaylistTrack.fromJson(supabaseJson);
      expect(supabaseTrack.isSupabase, isTrue);
      expect(supabaseTrack.isGeneral, isFalse);
      expect(supabaseTrack.songId, '1a3825f2-1b65-4615-9f03-c42722d73551');
      expect(supabaseTrack.trackId, isNull);

      // 2. General Track (Integer track_id)
      final generalJson = {
        'id': 'c13d7891-uuid',
        'schedule_id': 1,
        'song_id': null,
        'track_id': 42,
        'source': 'general',
        'title': 'Karma Police',
        'artist': 'Radiohead',
        'duration_seconds': 264,
        'play_order': 2,
      };

      final generalTrack = SchedulePlaylistTrack.fromJson(generalJson);
      expect(generalTrack.isGeneral, isTrue);
      expect(generalTrack.isSupabase, isFalse);
      expect(generalTrack.trackId, 42);
      expect(generalTrack.songId, isNull);

      // Verify batch payload preserves respective IDs
      final supabaseBatch = supabaseTrack.toBatchJson();
      expect(supabaseBatch['source'], 'supabase');
      expect(supabaseBatch['song_id'], '1a3825f2-1b65-4615-9f03-c42722d73551');

      final generalBatch = generalTrack.toBatchJson();
      expect(generalBatch['source'], 'general');
      expect(generalBatch['track_id'], 42);
    });

    test('AdminSchedule parses time range, dates, and publication status', () {
      final json = {
        'id': 1,
        'station_id': 1,
        'station_name': 'Radio Paradise',
        'title': 'Morning Acoustic Awakening',
        'schedule_date': '2026-10-31',
        'start_time': '09:00',
        'end_time': '12:00',
        'is_published': true,
        'song_count': 5,
        'songs': [
          {
            'id': 'c13d7890',
            'source': 'supabase',
            'song_id': '1a3825f2-uuid',
            'title': 'Teardrop',
            'artist': 'Massive Attack',
          }
        ],
      };

      final schedule = AdminSchedule.fromJson(json);

      expect(schedule.id, 1);
      expect(schedule.stationId, 1);
      expect(schedule.title, 'Morning Acoustic Awakening');
      expect(schedule.timeRange, '09:00 - 12:00');
      expect(schedule.isPublished, isTrue);
      expect(schedule.songCount, 5);
      expect(schedule.songs.length, 1);
      expect(schedule.songs.first.title, 'Teardrop');
    });
  });
}
