import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/note.dart';
import '../models/score.dart';
import '../services/audio_service.dart';

/// Central state manager for the score editor.
class ScoreNotifier extends ChangeNotifier {
  final Score score = Score();
  final AudioService _audioService = AudioService();

  /// Index where the next note will be inserted.
  int _cursorIndex = 0;
  int get cursorIndex => _cursorIndex;

  /// Currently selected note index (for editing/deleting). Null if none.
  int? _selectedIndex;
  int? get selectedIndex => _selectedIndex;

  /// Active duration for the next note to be input.
  NoteDuration _currentDuration = NoteDuration.quarter;
  NoteDuration get currentDuration => _currentDuration;

  /// Whether rest mode is active (next input creates a rest).
  bool _restMode = false;
  bool get restMode => _restMode;

  /// Playback state.
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Index of the note currently being played.
  int _playbackIndex = -1;
  int get playbackIndex => _playbackIndex;

  /// Whether the audio engine is initialized.
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the audio service.
  Future<void> init() async {
    await _audioService.init();
    _isInitialized = true;
    notifyListeners();
  }

  /// Set the active duration for future note input.
  void setDuration(NoteDuration duration) {
    _currentDuration = duration;
    notifyListeners();
  }

  /// Toggle rest mode.
  void toggleRestMode() {
    _restMode = !_restMode;
    notifyListeners();
  }

  /// Insert a note at the cursor position.
  /// If [midi] is provided, inserts a pitched note.
  /// If rest mode is on, inserts a rest.
  void insertNote(int midi) {
    final Note note;
    if (_restMode) {
      note = Note.rest(duration: _currentDuration);
    } else {
      note = Note(midi: midi, duration: _currentDuration);
    }

    score.addNote(note, _cursorIndex);
    _cursorIndex++;
    _selectedIndex = _cursorIndex - 1;

    // Play audio feedback for the note.
    if (!note.isRest) {
      _audioService.playNoteWithDuration(
        midi,
        duration: const Duration(milliseconds: 500),
      );
    }

    notifyListeners();
  }

  /// Select a note at the given index.
  void selectNote(int? index) {
    if (index != null && (index < 0 || index >= score.notes.length)) return;
    _selectedIndex = index;
    if (index != null) {
      _cursorIndex = index + 1;

      // Play audio feedback for selected note.
      final note = score.notes[index];
      if (!note.isRest) {
        _audioService.playNoteWithDuration(
          note.midi,
          duration: const Duration(milliseconds: 500),
        );
      }
    }
    notifyListeners();
  }

  /// Delete the currently selected note.
  void deleteSelected() {
    if (_selectedIndex == null) return;
    score.removeAt(_selectedIndex!);
    if (_cursorIndex > 0) _cursorIndex--;
    if (_selectedIndex! >= score.notes.length) {
      _selectedIndex = score.notes.isEmpty ? null : score.notes.length - 1;
    }
    notifyListeners();
  }

  /// Change the pitch of the selected note.
  void changeSelectedPitch(int midi) {
    if (_selectedIndex == null) return;
    final old = score.notes[_selectedIndex!];
    score.replaceAt(_selectedIndex!, old.copyWith(midi: midi));

    _audioService.playNoteWithDuration(
      midi,
      duration: const Duration(milliseconds: 500),
    );

    notifyListeners();
  }

  /// Change the duration of the selected note.
  void changeSelectedDuration(NoteDuration duration) {
    if (_selectedIndex == null) return;
    final old = score.notes[_selectedIndex!];
    score.replaceAt(_selectedIndex!, old.copyWith(duration: duration));
    notifyListeners();
  }

  /// Move cursor to a specific index.
  void moveCursor(int index) {
    _cursorIndex = index.clamp(0, score.notes.length);
    notifyListeners();
  }

  /// Start playing the score from the beginning.
  Future<void> play() async {
    if (score.notes.isEmpty || _isPlaying) return;

    _isPlaying = true;
    _playbackIndex = 0;
    notifyListeners();

    await _audioService.playScore(
      score,
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

  /// Stop playback.
  void stop() {
    _audioService.stopPlayback();
    _isPlaying = false;
    _playbackIndex = -1;
    notifyListeners();
  }

  /// Set tempo (BPM).
  void setTempo(double bpm) {
    score.bpm = bpm.clamp(40, 240);
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _audioService.dispose();
    super.dispose();
  }
}
