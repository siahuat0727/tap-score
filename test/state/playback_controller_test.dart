import 'dart:async';

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

  test('preload does not notify after dispose', () async {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(session.dispose);

    var listenerCalls = 0;
    playback.addListener(() {
      listenerCalls += 1;
    });

    final preloadFuture = playback.preload();
    expect(listenerCalls, 1);

    playback.dispose();
    final callsAfterDispose = listenerCalls;
    audioService.completePendingPreload(success: true);

    Object? thrown;
    try {
      await preloadFuture;
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isNull);
    expect(listenerCalls, callsAfterDispose);
  });

  test('dispose stops playback without notifying listeners', () {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(session.dispose);

    var listenerCalls = 0;
    playback.addListener(() {
      listenerCalls += 1;
    });

    playback.dispose();

    expect(audioService.stopCalls, 1);
    expect(listenerCalls, 0);
  });

  test('playback callbacks do not notify after dispose', () async {
    final audioService = _FakeAudioService()..holdPlayback = true;
    final session = EditableScoreSession();
    session.score.addNote(const Note(midi: 60));
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(session.dispose);

    var listenerCalls = 0;
    playback.addListener(() {
      listenerCalls += 1;
    });

    final playFuture = playback.play();
    expect(playback.isPlaying, isTrue);

    playback.dispose();
    final callsAfterDispose = listenerCalls;
    audioService.completePendingPlayback();

    Object? thrown;
    try {
      await playFuture;
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isNull);
    expect(listenerCalls, callsAfterDispose);
  });
}

class _FakeAudioService extends AudioService {
  final List<int> previewedMidis = [];
  final List<Score> playedScores = [];
  int stopCalls = 0;
  bool holdPlayback = false;
  AudioInitializationState _state = AudioInitializationState.idle;
  String? _error;
  Completer<bool>? _pendingPreload;
  Completer<void>? _pendingPlayback;

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
    if (_pendingPreload != null) {
      throw StateError('Preload is already pending.');
    }
    _state = AudioInitializationState.loading;
    _error = null;
    onStateChanged?.call();

    final pending = Completer<bool>();
    _pendingPreload = pending;
    final success = await pending.future;
    _pendingPreload = null;
    _state = success
        ? AudioInitializationState.ready
        : AudioInitializationState.error;
    _error = success ? null : 'Fake preload failed.';
    onStateChanged?.call();
    return success;
  }

  void completePendingPreload({required bool success}) {
    final pending = _pendingPreload;
    if (pending == null) {
      throw StateError('No pending preload.');
    }
    pending.complete(success);
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
    if (holdPlayback) {
      if (_pendingPlayback != null) {
        throw StateError('Playback is already pending.');
      }
      final pending = Completer<void>();
      _pendingPlayback = pending;
      await pending.future;
      _pendingPlayback = null;
      onNoteIndex(1);
    }
    onComplete();
  }

  void completePendingPlayback() {
    final pending = _pendingPlayback;
    if (pending == null) {
      throw StateError('No pending playback.');
    }
    pending.complete();
  }

  @override
  void stopPlayback() {
    stopCalls += 1;
  }

  @override
  void dispose() {}
}
