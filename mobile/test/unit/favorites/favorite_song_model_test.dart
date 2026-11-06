import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/features/admin/domain/models/admin_song.dart';
import 'package:pulsecast/features/favorites/domain/models/favorite_song.dart';
import 'package:pulsecast/features/library/domain/models/listener_track.dart';

void main() {
  group('FavoriteSong Domain Model Unit Tests', () {
    test('fromListenerTrack constructs general radio favorite with integer ID', () {
      const listenerTrack = ListenerTrack(
        id: 42,
        title: 'Teardrop',
        artist: 'Massive Attack',
        album: 'Mezzanine',
        stationId: 1,
        stationName: 'Radio Paradise',
        duration: '05:30',
        playOrder: 1,
        status: 'playing',
      );

      final fav = FavoriteSong.fromListenerTrack(listenerTrack);

      expect(fav.id, equals('general_42'));
      expect(fav.source, equals('general'));
      expect(fav.trackId, equals(42));
      expect(fav.songId, isNull);
      expect(fav.isGeneral, isTrue);
      expect(fav.isSupabase, isFalse);
      expect(fav.title, equals('Teardrop'));
      expect(fav.stationName, equals('Radio Paradise'));
      expect(fav.durationFormatted, equals('05:30'));
    });

    test('fromAdminSong constructs Supabase favorite with UUID songId', () {
      final adminSong = AdminSong(
        id: 'c838902b-a81d-4008-8df0-f94cfab99572',
        title: 'Resonance',
        artist: 'HOME',
        album: 'Odyssey',
        duration: '03:32',
        durationSeconds: 212,
        fileSizeBytes: 5242880,
        storageBucket: 'pulsecast-music-library',
        storagePath: 'music/resonance.mp3',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final fav = FavoriteSong.fromAdminSong(adminSong);

      expect(fav.id, equals('supabase_c838902b-a81d-4008-8df0-f94cfab99572'));
      expect(fav.source, equals('supabase'));
      expect(fav.songId, equals('c838902b-a81d-4008-8df0-f94cfab99572'));
      expect(fav.trackId, isNull);
      expect(fav.isSupabase, isTrue);
      expect(fav.isGeneral, isFalse);
      expect(fav.durationFormatted, equals('03:32'));
    });

    test('JSON round-trip preserves typed source separation', () {
      final generalFav = FavoriteSong(
        id: 'general_99',
        source: 'general',
        trackId: 99,
        title: 'Pacific Coast Highway',
        artist: 'Kavinsky',
        stationId: 2,
        stationName: 'Nightwave Plaza',
        duration: '03:55',
        favoritedAt: DateTime.parse('2026-11-01T12:00:00Z'),
      );

      final json = generalFav.toJson();
      final roundTrip = FavoriteSong.fromJson(json);

      expect(roundTrip.id, equals('general_99'));
      expect(roundTrip.source, equals('general'));
      expect(roundTrip.trackId, equals(99));
      expect(roundTrip.songId, isNull);
      expect(roundTrip.durationFormatted, equals('03:55'));
    });
  });
}
