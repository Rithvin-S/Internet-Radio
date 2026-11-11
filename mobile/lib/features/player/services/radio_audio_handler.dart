import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../../stations/domain/models/station.dart';
import '../domain/models/now_playing_info.dart';

/// Factory initializer creating the persistent system AudioService instance
Future<RadioAudioHandler> initAudioHandler() async {
  return await AudioService.init(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.pulsecast.radio.channel.audio',
      androidNotificationChannelName: 'PulseCast Radio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

/// Single persistent AudioHandler managing the internet radio lifecycle,
/// background playback, lock-screen controls, and reconnection logic.
class RadioAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  Station? _currentStation;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _reconnectTimer;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // Stream generation token and mutex guard to prevent duplicate / concurrent initializations
  int _streamGeneration = 0;
  bool _isLoadingStream = false;
  double _volume = 1.0;

  final _errorController = StreamController<String?>.broadcast(sync: true);
  Stream<String?> get errorStream => _errorController.stream;

  final _reconnectingController = StreamController<bool>.broadcast(sync: true);
  Stream<bool> get reconnectingStream => _reconnectingController.stream;

  RadioAudioHandler({AudioPlayer? player})
      : _player = player ??
            AudioPlayer(
              audioLoadConfiguration: const AudioLoadConfiguration(
                androidLoadControl: AndroidLoadControl(
                  minBufferDuration: Duration(seconds: 15),
                  maxBufferDuration: Duration(seconds: 30),
                  bufferForPlaybackDuration: Duration(milliseconds: 600),
                  bufferForPlaybackAfterRebufferDuration:
                      Duration(milliseconds: 1500),
                  prioritizeTimeOverSizeThresholds: true,
                ),
                darwinLoadControl: DarwinLoadControl(
                  preferredForwardBufferDuration: Duration(seconds: 15),
                  automaticallyWaitsToMinimizeStalling: true,
                ),
              ),
            ) {
    _initAudioSession();
    _listenToPlayerEvents();
  }

  Station? get currentStation => _currentStation;
  bool get isPlaying => _player.playing;
  bool get isLoadingStream => _isLoadingStream;
  double get volume => _volume;

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume((_volume * 0.3).clamp(0.0, 1.0));
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(_volume);
              break;
            case AudioInterruptionType.pause:
              play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      session.becomingNoisyEventStream.listen((_) {
        // Unplugged headphones: pause radio playback
        pause();
      });
    } catch (_) {
      // Audio session initialization error fallback
    }
  }

  void _listenToPlayerEvents() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      _broadcastState();
    });
  }

  void _broadcastState() {
    final playing = _player.playing;
    final processingState = _player.processingState;

    AudioProcessingState audioProcessingState;
    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        _reconnectAttempts = 0; // Reset on successful stream connection
        _reconnectingController.add(false);
        _isLoadingStream = false;
        break;
      case ProcessingState.completed:
        audioProcessingState = AudioProcessingState.completed;
        break;
    }

    playbackState.add(
      PlaybackState(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {},
        androidCompactActionIndices: const [0, 1],
        processingState: audioProcessingState,
        playing: playing,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ),
    );
  }

  /// Switches to and streams a selected radio station exactly once
  Future<void> playStation(Station station, {NowPlayingInfo? metadata}) async {
    // 1. Guard against duplicate calls while same station is already active or initializing
    if (_currentStation?.id == station.id) {
      if (_isLoadingStream ||
          _player.playing ||
          _player.processingState == ProcessingState.loading ||
          _player.processingState == ProcessingState.buffering) {
        return;
      }
      if (_player.processingState == ProcessingState.ready) {
        await _player.play();
        return;
      }
    }

    // 2. Invalidate previous generation and cancel any pending retry timers
    final generation = ++_streamGeneration;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _errorController.add(null);
    _reconnectingController.add(false);

    // Halt current stream cleanly without tearing down audio engine
    if (_player.playing) {
      await _player.pause();
    }
    _currentStation = station;

    // 3. Update system notification & lock-screen media item
    final title = metadata?.displayTitle ?? station.name;
    final artist = metadata?.displaySubtitle ?? (station.genre ?? 'PulseCast Live');

    mediaItem.add(
      MediaItem(
        id: station.id.toString(),
        album: station.genre ?? 'Live Radio',
        title: title,
        artist: artist,
        artUri: (station.artworkUrl != null && station.artworkUrl!.startsWith('http'))
            ? Uri.tryParse(station.artworkUrl!)
            : null,
      ),
    );

    // 4. Initialize and start stream exactly once for this generation
    await _loadAndPlayStream(station.effectiveStreamUrl, generation: generation);
  }

  Future<void> _loadAndPlayStream(String streamUrl, {required int generation}) async {
    if (generation != _streamGeneration) return;

    _isLoadingStream = true;
    _broadcastLoadingState();

    try {
      // Use preload: false so ExoPlayer sets source immediately without blocking,
      // and play() initiates immediate streaming with fast buffer control.
      await _player.setUrl(streamUrl, preload: false);
      if (generation != _streamGeneration) return;

      await _player.play();
      if (generation != _streamGeneration) return;

      _errorController.add(null);
    } catch (e) {
      if (generation != _streamGeneration) return;

      final errStr = e.toString().toLowerCase();
      // Ignore normal connection cancellations caused by switching stations
      if (errStr.contains('abort') ||
          errStr.contains('interrupted') ||
          errStr.contains('cancel')) {
        return;
      }

      _handlePlaybackError(e.toString(), streamUrl, generation);
    } finally {
      if (generation == _streamGeneration) {
        _isLoadingStream = false;
      }
    }
  }

  void _broadcastLoadingState() {
    playbackState.add(
      PlaybackState(
        controls: [MediaControl.stop],
        systemActions: const {},
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.loading,
        playing: false,
      ),
    );
  }

  void _handlePlaybackError(String error, String streamUrl, int generation) {
    if (generation != _streamGeneration) return;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delaySeconds = 2 * _reconnectAttempts; // Bounded backoff: 2s, 4s, 6s
      _reconnectingController.add(true);
      _errorController.add(
        'Stream interrupted. Reconnecting (attempt $_reconnectAttempts/$_maxReconnectAttempts)...',
      );

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (generation == _streamGeneration && _currentStation != null) {
          _loadAndPlayStream(streamUrl, generation: generation);
        }
      });
    } else {
      _reconnectingController.add(false);
      _errorController.add(
        'Unable to connect to "${_currentStation?.name ?? 'station'}". The stream may be currently offline.',
      );
      stop();
    }
  }

  /// Updates Now Playing metadata on active notification without interrupting stream
  void updateMetadata(NowPlayingInfo metadata) {
    if (_currentStation == null) return;
    final current = mediaItem.value;

    mediaItem.add(
      MediaItem(
        id: _currentStation!.id.toString(),
        album: _currentStation!.genre ?? 'Live Radio',
        title: metadata.displayTitle,
        artist: metadata.displaySubtitle,
        artUri: current?.artUri,
      ),
    );
  }

  @override
  Future<void> play() async {
    _errorController.add(null);
    if (_currentStation != null && _player.processingState == ProcessingState.idle) {
      final gen = ++_streamGeneration;
      await _loadAndPlayStream(_currentStation!.effectiveStreamUrl, generation: gen);
    } else {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    _reconnectTimer?.cancel();
    _reconnectingController.add(false);
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _streamGeneration++;
    _isLoadingStream = false;
    _reconnectTimer?.cancel();
    _reconnectingController.add(false);
    _currentStation = null;
    mediaItem.add(null);
    await _player.stop();
    _broadcastState();
  }

  Future<void> dispose() async {
    _streamGeneration++;
    _isLoadingStream = false;
    _reconnectTimer?.cancel();
    _playerStateSubscription?.cancel();
    if (!_errorController.isClosed) {
      _errorController.close();
    }
    if (!_reconnectingController.isClosed) {
      _reconnectingController.close();
    }
    _player.dispose();
  }
}
