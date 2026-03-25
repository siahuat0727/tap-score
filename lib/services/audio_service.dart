import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_midi_pro/flutter_midi_pro.dart';

import '../models/score.dart';
import 'playback_schedule.dart';
import 'web_audio_stub.dart'
    if (dart.library.js) 'web_audio_impl.dart'
    as web_audio;

enum AudioInitializationState { idle, loading, ready, error }

/// Service wrapping flutter_midi_pro for SoundFont-based piano playback.
///
/// On Web, uses Web Audio API with bundled MP3 samples.
class AudioNoteHandle {
  final int id;
  final int midi;

  const AudioNoteHandle({required this.id, required this.midi});
}

class AudioService {
  AudioService({bool testMode = false}) : _testMode = testMode;

  static const int defaultPlaybackVelocity = 100;
  static const int rhythmTestMelodyVelocity = 90;
  static const int _accentedMetronomeMidi = 84;
  static const int _regularMetronomeMidi = 76;
  static const int _rhythmTestAccentedMetronomeVelocity = 48;
  static const int _rhythmTestRegularMetronomeVelocity = 36;

  final bool _testMode;
  final MidiPro _midiPro = MidiPro();
  final Map<int, AudioNoteHandle> _activeNoteHandles = {};
  int? _sfId;
  bool _initialized = false;
  AudioInitializationState _initializationState = AudioInitializationState.idle;
  String? _initializationError;
  Future<bool>? _initializationFuture;
  bool _stopRequested = false;
  int _nextNativeHandleId = 1;

  void Function()? onStateChanged;

  AudioInitializationState get initializationState => _initializationState;
  String? get initializationError => _initializationError;
  bool get isInitialized => _initialized;

  /// Whether this platform supports MIDI playback.
  bool get _platformSupported {
    if (kIsWeb) return true; // Web uses Web Audio API
    // macOS is disabled: flutter_midi_pro uses AVAudioUnitSampler which
    // causes native CoreAudio assertion crashes on macOS 26.x.
    // Audio works fine on iOS and Android (the primary targets).
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Initialize by loading the bundled SoundFont.
  Future<bool> init() async {
    return _ensureInitialized();
  }

  Future<bool> preload() async {
    return _ensureInitialized();
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    if (_testMode) {
      _initialized = true;
      return true;
    }
    if (_initializationFuture != null) {
      return _initializationFuture!;
    }
    if (!_platformSupported) {
      _setInitializationState(
        AudioInitializationState.error,
        errorMessage: 'Audio playback is unavailable on this platform.',
      );
      return false;
    }

    _setInitializationState(AudioInitializationState.loading);

    _initializationFuture = _performInitialization();
    final initialized = await _initializationFuture!;
    _initializationFuture = null;
    return initialized;
  }

  Future<bool> _performInitialization() async {
    if (_initialized) {
      _setInitializationState(AudioInitializationState.ready);
      return true;
    }

    if (kIsWeb) {
      try {
        _initialized = await web_audio.initWebAudio();
        _setInitializationState(
          _initialized
              ? AudioInitializationState.ready
              : AudioInitializationState.error,
          errorMessage: _initialized
              ? null
              : 'Piano audio failed to initialize.',
        );
      } catch (error) {
        _initialized = false;
        _setInitializationState(
          AudioInitializationState.error,
          errorMessage: error.toString(),
        );
      }

      return _initialized;
    }

    try {
      _sfId = await _midiPro.loadSoundfontAsset(
        assetPath: 'assets/soundfonts/piano.sf2',
        bank: 0,
        program: 0,
      );
      _initialized = true;
      _setInitializationState(AudioInitializationState.ready);
      return true;
    } catch (error) {
      _initialized = false;
      _setInitializationState(
        AudioInitializationState.error,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  void _setInitializationState(
    AudioInitializationState state, {
    String? errorMessage,
  }) {
    final didChange =
        _initializationState != state || _initializationError != errorMessage;
    _initializationState = state;
    _initializationError = errorMessage;
    if (state != AudioInitializationState.error) {
      _initializationError = null;
    }
    if (didChange) {
      onStateChanged?.call();
    }
  }

  /// Start a single note and return its playback handle.
  Future<AudioNoteHandle?> startNote(
    int midi, {
    int velocity = defaultPlaybackVelocity,
  }) async {
    if (!await _ensureInitialized()) return null;

    final clampedMidi = midi.clamp(0, 127);
    if (kIsWeb) {
      final handleId = web_audio.playWebNote(clampedMidi, velocity);
      if (handleId < 0) {
        return null;
      }

      final handle = AudioNoteHandle(id: handleId, midi: clampedMidi);
      _activeNoteHandles[handle.id] = handle;
      return handle;
    }

    if (_sfId == null) return null;

    try {
      await _midiPro.playNote(
        sfId: _sfId!,
        channel: 0,
        key: clampedMidi,
        velocity: velocity,
      );

      final handle = AudioNoteHandle(
        id: _nextNativeHandleId++,
        midi: clampedMidi,
      );
      _activeNoteHandles[handle.id] = handle;
      return handle;
    } catch (e) {
      return null;
    }
  }

  Future<void> stopNoteHandle(AudioNoteHandle handle) async {
    if (!_initialized) return;

    _activeNoteHandles.remove(handle.id);

    if (kIsWeb) {
      web_audio.stopWebNote(handle.id);
      return;
    }

    if (_sfId == null) return;

    try {
      await _midiPro.stopNote(sfId: _sfId!, channel: 0, key: handle.midi);
    } catch (e) {
      // Keep playback resilient to platform stop errors.
    }
  }

  /// Play a single note for a fixed duration (for input/selection feedback).
  void playNoteWithDuration(
    int midi, {
    Duration duration = const Duration(milliseconds: 400),
    int velocity = defaultPlaybackVelocity,
  }) {
    unawaited(
      _playNoteWithScheduledStop(midi, duration: duration, velocity: velocity),
    );
  }

  /// Play a short metronome click.
  void playMetronomeClick({required bool accented}) {
    playNoteWithDuration(
      accented ? _accentedMetronomeMidi : _regularMetronomeMidi,
      duration: const Duration(milliseconds: 90),
    );
  }

  void playRhythmTestMetronomeClick({required bool accented}) {
    playNoteWithDuration(
      accented ? _accentedMetronomeMidi : _regularMetronomeMidi,
      duration: const Duration(milliseconds: 90),
      velocity: accented
          ? _rhythmTestAccentedMetronomeVelocity
          : _rhythmTestRegularMetronomeVelocity,
    );
  }

  /// Play the entire score using the shared playback schedule.
  Future<void> playScore(
    Score score, {
    required void Function(int index) onNoteIndex,
    required void Function() onComplete,
  }) async {
    await playPlaybackTimeline(
      buildScorePlaybackTimeline(score),
      onNoteIndex: onNoteIndex,
      onComplete: onComplete,
    );
  }

  Future<void> playPlaybackTimeline(
    ScorePlaybackTimeline timeline, {
    required void Function(int index) onNoteIndex,
    required void Function() onComplete,
  }) async {
    if (!await _ensureInitialized()) {
      onComplete();
      return;
    }

    _stopRequested = false;
    final activeHandlesByNoteIndex = <int, AudioNoteHandle>{};
    final events =
        <_PlaybackTimelineEvent>[
          for (final step in timeline.steps)
            _StepPlaybackEvent(
              targetMicros: (step.startSeconds * Duration.microsecondsPerSecond)
                  .round(),
              noteIndex: step.noteIndex,
            ),
          for (final event in buildScheduledPlaybackEvents(
            timeline.playbackNotes,
          ))
            _AudioPlaybackEvent(event),
        ]..sort((a, b) {
          final targetCompare = a.targetMicros.compareTo(b.targetMicros);
          if (targetCompare != 0) {
            return targetCompare;
          }
          return a.sortOrder.compareTo(b.sortOrder);
        });

    final stopwatch = Stopwatch()..start();
    for (final event in events) {
      if (!await _waitUntil(stopwatch, event.targetMicros)) {
        await _stopActiveHandles(activeHandlesByNoteIndex.values);
        return;
      }

      switch (event) {
        case _StepPlaybackEvent():
          onNoteIndex(event.noteIndex);
        case _AudioPlaybackEvent():
          switch (event.event.type) {
            case ScheduledPlaybackEventType.noteOff:
              final handle = activeHandlesByNoteIndex.remove(
                event.event.note.noteIndex,
              );
              if (handle != null) {
                await stopNoteHandle(handle);
              }
            case ScheduledPlaybackEventType.noteOn:
              final handle = await startNote(
                event.event.note.midi,
                velocity: event.event.note.velocity,
              );
              if (handle != null) {
                activeHandlesByNoteIndex[event.event.note.noteIndex] = handle;
              }
          }
      }
    }

    final finishMicros =
        (timeline.totalDurationSeconds * Duration.microsecondsPerSecond)
            .round();
    if (!await _waitUntil(stopwatch, finishMicros)) {
      await _stopActiveHandles(activeHandlesByNoteIndex.values);
      return;
    }

    await _stopActiveHandles(activeHandlesByNoteIndex.values);
    if (!_stopRequested) {
      onComplete();
    }
  }

  Future<void> _playNoteWithScheduledStop(
    int midi, {
    required Duration duration,
    required int velocity,
  }) async {
    final handle = await startNote(midi, velocity: velocity);
    if (handle == null) {
      return;
    }

    Timer(duration, () {
      unawaited(stopNoteHandle(handle));
    });
  }

  Future<bool> _waitUntil(Stopwatch stopwatch, int targetMicros) async {
    while (!_stopRequested) {
      final remainingMicros = targetMicros - stopwatch.elapsedMicroseconds;
      if (remainingMicros <= 0) {
        return true;
      }

      final sleepMicros = remainingMicros > 16000 ? 16000 : remainingMicros;
      await Future<void>.delayed(Duration(microseconds: sleepMicros));
    }

    return false;
  }

  Future<void> _stopActiveHandles(Iterable<AudioNoteHandle> handles) async {
    for (final handle in List<AudioNoteHandle>.from(handles)) {
      await stopNoteHandle(handle);
    }
  }

  /// Stop ongoing playback.
  void stopPlayback() {
    _stopRequested = true;
    if (!_initialized) {
      return;
    }

    if (kIsWeb) {
      for (final handle in _activeNoteHandles.values.toList()) {
        web_audio.stopWebNote(handle.id);
      }
      _activeNoteHandles.clear();
      return;
    }

    if (_sfId == null) {
      return;
    }

    try {
      for (final handle in _activeNoteHandles.values.toList()) {
        _midiPro.stopNote(sfId: _sfId!, channel: 0, key: handle.midi);
      }
      _activeNoteHandles.clear();
    } catch (e) {
      // Keep playback resilient to platform stop errors.
    }
  }

  /// Clean up resources.
  void dispose() {
    stopPlayback();
    onStateChanged = null;
  }
}

sealed class _PlaybackTimelineEvent {
  const _PlaybackTimelineEvent({
    required this.targetMicros,
    required this.sortOrder,
  });

  final int targetMicros;
  final int sortOrder;
}

class _StepPlaybackEvent extends _PlaybackTimelineEvent {
  const _StepPlaybackEvent({
    required super.targetMicros,
    required this.noteIndex,
  }) : super(sortOrder: 1);

  final int noteIndex;
}

class _AudioPlaybackEvent extends _PlaybackTimelineEvent {
  _AudioPlaybackEvent(this.event)
    : super(
        targetMicros: event.targetMicros,
        sortOrder: switch (event.type) {
          ScheduledPlaybackEventType.noteOff => 0,
          ScheduledPlaybackEventType.noteOn => 2,
        },
      );

  final ScheduledPlaybackEvent event;
}
