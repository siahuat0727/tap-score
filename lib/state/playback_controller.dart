import 'package:flutter/foundation.dart';

import '../services/audio_service.dart';
import 'editable_score_session.dart';

enum AudioStatus { idle, preloading, ready, error }

class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required EditableScoreSession session,
    AudioService? audioService,
  }) : _session = session,
       _audioService = audioService ?? AudioService() {
    _audioService.onStateChanged = _syncAudioState;
    _syncAudioState(notify: false);
  }

  final EditableScoreSession _session;
  final AudioService _audioService;

  bool _isPlaying = false;
  int _playbackIndex = -1;
  AudioStatus _audioStatus = AudioStatus.idle;
  String? _audioStatusMessage;

  bool get isPlaying => _isPlaying;
  int get playbackIndex => _playbackIndex;
  AudioStatus get audioStatus => _audioStatus;
  bool get isInitialized => _audioStatus == AudioStatus.ready;
  String? get audioStatusMessage => _audioStatusMessage;
  bool get audioStatusIsError => _audioStatus == AudioStatus.error;

  void previewNote(
    int midi, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    _audioService.playNoteWithDuration(midi, duration: duration);
  }

  Future<void> preload() {
    return _audioService.preload().then((_) => _syncAudioState());
  }

  Future<void> play() async {
    if (_session.score.notes.isEmpty || _isPlaying) return;

    _isPlaying = true;
    _playbackIndex = 0;
    notifyListeners();

    await _audioService.playScore(
      _session.score,
      onNoteIndex: (index) {
        _playbackIndex = index;
        notifyListeners();
      },
      onComplete: () {
        _isPlaying = false;
        _playbackIndex = -1;
        notifyListeners();
      },
    );
  }

  void stop() {
    _audioService.stopPlayback();
    _isPlaying = false;
    _playbackIndex = -1;
    notifyListeners();
  }

  void _syncAudioState({bool notify = true}) {
    final previousStatus = _audioStatus;
    final previousMessage = _audioStatusMessage;

    switch (_audioService.initializationState) {
      case AudioInitializationState.idle:
        _audioStatus = AudioStatus.idle;
        _audioStatusMessage = null;
      case AudioInitializationState.loading:
        _audioStatus = AudioStatus.preloading;
        _audioStatusMessage = 'Preparing piano audio...';
      case AudioInitializationState.ready:
        _audioStatus = AudioStatus.ready;
        _audioStatusMessage = null;
      case AudioInitializationState.error:
        _audioStatus = AudioStatus.error;
        _audioStatusMessage =
            _audioService.initializationError ??
            'Piano audio failed to initialize.';
    }

    if (notify &&
        (previousStatus != _audioStatus ||
            previousMessage != _audioStatusMessage)) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stop();
    _audioService.onStateChanged = null;
    _audioService.dispose();
    super.dispose();
  }
}
