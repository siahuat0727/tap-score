import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/services/audio_service.dart';
import 'package:tap_score/state/editable_score_session.dart';
import 'package:tap_score/state/playback_controller.dart';

void main() {
  test('syncs audio initialization state into public audio status', () async {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(playback.dispose);
    addTearDown(session.dispose);

    expect(playback.audioStatus, AudioStatus.idle);

    await audioService.completePreload(success: true);

    expect(playback.audioStatus, AudioStatus.ready);
    expect(playback.audioStatusMessage, isNull);
  });

  test('previewNote forwards a short note to audio service', () {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(playback.dispose);
    addTearDown(session.dispose);

    playback.previewNote(64);

    expect(audioService.previewedMidis, [64]);
  });

  test('play reads the session score and updates playback state', () async {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    session.score.addNote(const Note(midi: 60, duration: NoteDuration.quarter));
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(playback.dispose);
    addTearDown(session.dispose);

    await playback.play();

    expect(audioService.playedScores.single.notes.single.midi, 60);
    expect(playback.isPlaying, isFalse);
    expect(playback.playbackIndex, -1);
  });

  test('stop resets state and stops the audio service', () {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    session.score.addNote(const Note(midi: 60));
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(playback.dispose);
    addTearDown(session.dispose);

    playback.stop();

    expect(audioService.stopCalls, 1);
    expect(playback.isPlaying, isFalse);
    expect(playback.playbackIndex, -1);
  });
}

class _FakeAudioService extends AudioService {
  final List<int> previewedMidis = [];
  final List<Score> playedScores = [];
  int stopCalls = 0;
  AudioInitializationState _state = AudioInitializationState.idle;
  String? _error;

  @override
  AudioInitializationState get initializationState => _state;

  @override
  String? get initializationError => _error;

  Future<bool> completePreload({required bool success}) async {
    _state = AudioInitializationState.loading;
    onStateChanged?.call();
    _state = success
        ? AudioInitializationState.ready
        : AudioInitializationState.error;
    _error = success ? null : 'Fake preload failed.';
    onStateChanged?.call();
    return success;
  }

  @override
  Future<bool> preload({
    Duration webTimeout = const Duration(seconds: 12),
  }) async {
    return completePreload(success: true);
  }

  @override
  void playNoteWithDuration(
    int midi, {
    Duration duration = const Duration(milliseconds: 400),
    int velocity = AudioService.defaultPlaybackVelocity,
  }) {
    previewedMidis.add(midi);
  }

  @override
  Future<void> playScore(
    Score score, {
    required void Function(int index) onNoteIndex,
    required void Function() onComplete,
  }) async {
    playedScores.add(score.copy());
    onNoteIndex(0);
    onComplete();
  }

  @override
  void stopPlayback() {
    stopCalls += 1;
  }

  @override
  void dispose() {}
}
