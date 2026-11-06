import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// In-memory Fake AudioPlayer simulating audio engine events without native platform channels
class FakeAudioPlayer extends AudioPlayer {
  bool _fakePlaying = false;
  ProcessingState _fakeProcessingState = ProcessingState.idle;
  String? _loadedUrl;
  bool shouldThrowOnSetUrl = false;

  final _playerStateController = StreamController<PlayerState>.broadcast(sync: true);
  final _playbackEventController = StreamController<PlaybackEvent>.broadcast(sync: true);

  FakeAudioPlayer() : super();

  @override
  bool get playing => _fakePlaying;

  @override
  ProcessingState get processingState => _fakeProcessingState;

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _playbackEventController.stream;

  String? get loadedUrl => _loadedUrl;

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    if (shouldThrowOnSetUrl) {
      _fakeProcessingState = ProcessingState.idle;
      _fakePlaying = false;
      _emitState();
      throw Exception('Network connection refused');
    }

    _loadedUrl = url;
    _fakeProcessingState = ProcessingState.ready;
    _emitState();
    return null;
  }

  @override
  Future<void> play() async {
    _fakePlaying = true;
    _fakeProcessingState = ProcessingState.ready;
    _emitState();
  }

  @override
  Future<void> pause() async {
    _fakePlaying = false;
    _emitState();
  }

  @override
  Future<void> stop() async {
    _fakePlaying = false;
    _fakeProcessingState = ProcessingState.idle;
    _emitState();
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    if (!_playerStateController.isClosed) {
      _playerStateController.close();
    }
    if (!_playbackEventController.isClosed) {
      _playbackEventController.close();
    }
  }

  void _emitState() {
    _playerStateController.add(PlayerState(_fakePlaying, _fakeProcessingState));
    _playbackEventController.add(PlaybackEvent(
      processingState: _fakeProcessingState,
      updatePosition: Duration.zero,
    ));
  }
}

