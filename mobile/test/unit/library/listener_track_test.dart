import 'package:flutter_test/flutter_test.dart';
import 'package:pulsecast/features/library/domain/models/listener_track.dart';

void main() {
  group('ListenerTrack Domain Model Tests', () {
    test('Correctly parses track from station JSON with active playing status', () {
      final json = {
        'id': 101,
        'station_id': 1,
        'station_name': 'Radio Paradise (Main Mix)',
        'title': 'Teardrop',
        'artist': 'Massive Attack',
        'album': 'Mezzanine',
        'duration': '05:30',
        'play_order': 1,
        'status': 'playing',
        'created_at': '2026-10-31T12:00:00.000Z',
      };

      final track = ListenerTrack.fromJson(json);

      expect(track.id, 101);
      expect(track.stationId, 1);
      expect(track.stationName, 'Radio Paradise (Main Mix)');
      expect(track.title, 'Teardrop');
      expect(track.artist, 'Massive Attack');
      expect(track.album, 'Mezzanine');
      expect(track.duration, '05:30');
      expect(track.playOrder, 1);
      expect(track.status, 'playing');
      expect(track.isCurrentlyPlaying, isTrue);
      expect(track.isQueued, isFalse);
    });

    test('Correctly parses queued track and handles string IDs gracefully', () {
      final json = {
        'id': '202',
        'station_id': '2',
        'title': 'Karma Police',
        'artist': 'Radiohead',
        'status': 'queued',
      };

      final track = ListenerTrack.fromJson(
        json,
        defaultStationName: 'Nightwave Plaza',
      );

      expect(track.id, 202);
      expect(track.stationId, 2);
      expect(track.stationName, 'Nightwave Plaza');
      expect(track.isCurrentlyPlaying, isFalse);
      expect(track.isQueued, isTrue);
    });

    test('toJson produces expected map serialization', () {
      const track = ListenerTrack(
        id: 5,
        stationId: 1,
        stationName: 'Radio Paradise',
        title: 'Breathe',
        artist: 'Pink Floyd',
        album: 'Dark Side of the Moon',
        duration: '02:43',
        status: 'queued',
      );

      final json = track.toJson();

      expect(json['id'], 5);
      expect(json['station_id'], 1);
      expect(json['title'], 'Breathe');
      expect(json['status'], 'queued');
    });
  });
}
