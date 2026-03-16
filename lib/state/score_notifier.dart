import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/enums.dart';
import '../models/key_signature.dart';
import '../models/note.dart';
import '../models/score.dart';
import '../services/audio_service.dart';

/// What kind of element is currently selected.
enum SelectionKind { timeSig, keySig, note }

/// Central state manager for the score editor.
class ScoreNotifier extends ChangeNotifier {
  final Score score = Score();
  final AudioService _audioService = AudioService();

  /// Index where the next note will be inserted.
  int _cursorIndex = 0;
  int get cursorIndex => _cursorIndex;

  /// What kind of element is selected. Null = cursor at end (input mode).
  SelectionKind? _selectionKind;
  SelectionKind? get selectionKind => _selectionKind;

  /// Currently selected note index (valid only when _selectionKind == note).
  int? _selectedNoteIndex;
  int? get selectedIndex =>
      _selectionKind == SelectionKind.note ? _selectedNoteIndex : null;

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
  void insertNote(int rawMidi) {
    final Note note;
    if (_restMode) {
      note = Note.rest(duration: _currentDuration);
    } else {
      // Auto-apply key signature accidentals to the raw MIDI.
      final midi = score.keySignature.applyToMidi(rawMidi);
      note = Note(midi: midi, duration: _currentDuration);
    }

    score.addNote(note, _cursorIndex);
    _cursorIndex++;
    _selectionKind = SelectionKind.note;
    _selectedNoteIndex = _cursorIndex - 1;

    // Play audio feedback for the note.
    if (!note.isRest) {
      _audioService.playNoteWithDuration(
        note.midi,
        duration: const Duration(milliseconds: 500),
      );
    }

    notifyListeners();
  }

  /// Select a note at the given index, or deselect (cursor at end) when null.
  void selectNote(int? index) {
    if (index != null && (index < 0 || index >= score.notes.length)) return;
    if (index != null) {
      _selectionKind = SelectionKind.note;
      _selectedNoteIndex = index;
      _cursorIndex = index + 1;

      // Play audio feedback for selected note.
      final note = score.notes[index];
      if (!note.isRest) {
        _audioService.playNoteWithDuration(
          note.midi,
          duration: const Duration(milliseconds: 500),
        );
      }
    } else {
      _selectionKind = null;
      _selectedNoteIndex = null;
      _cursorIndex = score.notes.length;
    }
    notifyListeners();
  }

  /// Select the time signature element.
  void selectTimeSig() {
    _selectionKind = SelectionKind.timeSig;
    _selectedNoteIndex = null;
    _cursorIndex = 0;
    notifyListeners();
  }

  /// Select the key signature element.
  void selectKeySig() {
    _selectionKind = SelectionKind.keySig;
    _selectedNoteIndex = null;
    _cursorIndex = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Navigation (← / →)
  // ---------------------------------------------------------------------------

  /// Move selection one step to the left.
  /// Order: cursor(end) → note[n-1] → ... → note[0] → keySig → timeSig
  void moveSelectionLeft() {
    switch (_selectionKind) {
      case null:
        // At cursor/end — select last note if any, else keySig.
        if (score.notes.isNotEmpty) {
          selectNote(score.notes.length - 1);
        } else {
          selectKeySig();
        }
      case SelectionKind.note:
        final idx = _selectedNoteIndex ?? 0;
        if (idx > 0) {
          selectNote(idx - 1);
        } else {
          selectKeySig();
        }
      case SelectionKind.keySig:
        selectTimeSig();
      case SelectionKind.timeSig:
        break; // already leftmost
    }
  }

  /// Move selection one step to the right.
  /// Order: timeSig → keySig → note[0] → ... → note[n-1] → cursor(end)
  void moveSelectionRight() {
    switch (_selectionKind) {
      case SelectionKind.timeSig:
        selectKeySig();
      case SelectionKind.keySig:
        if (score.notes.isNotEmpty) {
          selectNote(0);
        } else {
          selectNote(null); // go to cursor/end
        }
      case SelectionKind.note:
        final idx = _selectedNoteIndex ?? 0;
        if (idx < score.notes.length - 1) {
          selectNote(idx + 1);
        } else {
          selectNote(null); // go to cursor/end
        }
      case null:
        break; // already at end
    }
  }

  // ---------------------------------------------------------------------------
  // Adjust selected element (↑ / ↓)
  // ---------------------------------------------------------------------------

  /// Adjust the selected element up (+1) or down (-1).
  void adjustSelection(int direction) {
    switch (_selectionKind) {
      case SelectionKind.timeSig:
        adjustBeatsPerMeasure(direction);
      case SelectionKind.keySig:
        shiftKeySignature(direction);
      case SelectionKind.note:
        _diatonicStepSelected(direction);
      case null:
        break; // cursor at end — nothing to adjust
    }
  }

  /// Move the selected note by one diatonic step.
  void _diatonicStepSelected(int direction) {
    if (_selectedNoteIndex == null) return;
    final note = score.notes[_selectedNoteIndex!];
    if (note.isRest) return;
    final newMidi = score.keySignature.diatonicStep(note.midi, direction);
    if (newMidi == note.midi) return;
    score.replaceAt(_selectedNoteIndex!, note.copyWith(midi: newMidi));
    _audioService.playNoteWithDuration(
      newMidi,
      duration: const Duration(milliseconds: 500),
    );
    notifyListeners();
  }

  /// Delete the currently selected note.
  void deleteSelected() {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null)
      return;
    score.removeAt(_selectedNoteIndex!);
    if (_cursorIndex > 0) _cursorIndex--;
    if (_selectedNoteIndex! >= score.notes.length) {
      _selectedNoteIndex = score.notes.isEmpty ? null : score.notes.length - 1;
    }
    if (_selectedNoteIndex == null) _selectionKind = null;
    notifyListeners();
  }

  /// Change the pitch of the selected note.
  void changeSelectedPitch(int midi) {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return;
    }
    final old = score.notes[_selectedNoteIndex!];
    score.replaceAt(_selectedNoteIndex!, old.copyWith(midi: midi));

    _audioService.playNoteWithDuration(
      midi,
      duration: const Duration(milliseconds: 500),
    );

    notifyListeners();
  }

  /// Change the duration of the selected note.
  void changeSelectedDuration(NoteDuration duration) {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return;
    }
    final old = score.notes[_selectedNoteIndex!];
    score.replaceAt(_selectedNoteIndex!, old.copyWith(duration: duration));
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

  // ---------------------------------------------------------------------------
  // Time signature
  // ---------------------------------------------------------------------------

  /// Set time signature (e.g. 3/4, 6/8).
  void setTimeSignature(int beats, int unit) {
    score.beatsPerMeasure = beats.clamp(1, 16);
    score.beatUnit = unit;
    notifyListeners();
  }

  /// Nudge beats-per-measure up or down by one step.
  void adjustBeatsPerMeasure(int delta) {
    setTimeSignature(score.beatsPerMeasure + delta, score.beatUnit);
  }

  // ---------------------------------------------------------------------------
  // Key signature
  // ---------------------------------------------------------------------------

  /// Set key signature explicitly.
  void setKeySignature(KeySignature key) {
    score.keySignature = key;
    notifyListeners();
  }

  /// Shift key signature one step on the circle of fifths.
  /// [direction] > 0 = add sharp (clockwise), < 0 = add flat (counter-clockwise).
  void shiftKeySignature(int direction) {
    final next = direction > 0
        ? score.keySignature.nextSharp
        : score.keySignature.nextFlat;
    setKeySignature(next);
  }

  @override
  void dispose() {
    stop();
    _audioService.dispose();
    super.dispose();
  }
}
