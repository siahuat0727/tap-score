import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import '../models/score.dart';
import 'web_audio_stub.dart'
    if (dart.library.js) 'web_audio_impl.dart'
    as web_audio;

/// Service wrapping flutter_midi_pro for SoundFont-based piano playback.
///
/// On Web, uses Web Audio API with bundled MP3 samples.
class AudioService {
  static const int _accentedMetronomeMidi = 84;
  static const int _regularMetronomeMidi = 76;

  final MidiPro _midiPro = MidiPro();
  int? _sfId;
  bool _initialized = false;
  bool _stopRequested = false;

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
    if (_initialized) return true;
    if (!_platformSupported) return false;

    if (kIsWeb) {
      try {
        _initialized = await web_audio.initWebAudio();
      } catch (e) {
        _initialized = false;
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
      return true;
    } catch (e) {
      _initialized = false;
      return false;
    }
  }

  /// Play a single MIDI note.
  Future<void> playNote(int midi, {int velocity = 100}) async {
    if (!_initialized) return;

    if (kIsWeb) {
      web_audio.playWebNote(midi.clamp(0, 127), velocity);
      return;
    }

    if (_sfId == null) return;

    try {
      await _midiPro.playNote(
        sfId: _sfId!,
        channel: 0,
        key: midi.clamp(0, 127),
        velocity: velocity,
      );
    } catch (e) {
      // Gracefully handle audio errors.
    }
  }

  /// Stop a single MIDI note.
  Future<void> stopNote(int midi) async {
    if (!_initialized) return;

    if (kIsWeb) {
      web_audio.stopWebNote(midi.clamp(0, 127));
      return;
    }

    if (_sfId == null) return;

    try {
      await _midiPro.stopNote(
        sfId: _sfId!,
        channel: 0,
        key: midi.clamp(0, 127),
      );
    } catch (e) {
      // Gracefully handle audio errors.
    }
  }

  /// Play a single note for a fixed duration (for input/selection feedback).
  void playNoteWithDuration(
    int midi, {
    Duration duration = const Duration(milliseconds: 400),
  }) {
    playNote(midi);
    Timer(duration, () => stopNote(midi));
  }

  /// Play a short metronome click.
  void playMetronomeClick({required bool accented}) {
    playNoteWithDuration(
      accented ? _accentedMetronomeMidi : _regularMetronomeMidi,
      duration: const Duration(milliseconds: 90),
    );
  }

  /// Play the entire score sequentially.
  Future<void> playScore(
    Score score, {
    required void Function(int index) onNoteIndex,
    required void Function() onComplete,
  }) async {
    _stopRequested = false;

    for (int i = 0; i < score.notes.length; i++) {
      if (_stopRequested) break;

      final note = score.notes[i];
      onNoteIndex(i);

      if (!note.isRest) {
        await playNote(note.midi);
      }

      final durationMs = (note.effectiveBeats * score.secondsPerBeat * 1000)
          .round();
      await Future.delayed(Duration(milliseconds: durationMs));

      if (!note.isRest) {
        await stopNote(note.midi);
      }
    }

    if (!_stopRequested) {
      onComplete();
    }
  }

  /// Stop ongoing playback.
  void stopPlayback() {
    _stopRequested = true;
    if (_initialized) {
      if (kIsWeb) {
        for (int i = 0; i < 128; i++) {
          web_audio.stopWebNote(i);
        }
        return;
      }

      if (_sfId != null) {
        try {
          for (int i = 0; i < 128; i++) {
            _midiPro.stopNote(sfId: _sfId!, channel: 0, key: i);
          }
        } catch (e) {
          // Gracefully handle audio errors.
        }
      }
    }
  }

  /// Clean up resources.
  void dispose() {
    stopPlayback();
  }
}
