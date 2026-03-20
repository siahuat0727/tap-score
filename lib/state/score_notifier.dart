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

  /// Whether dotted mode is active (next input creates a dotted note).
  bool _dottedMode = false;
  bool get dottedMode => _dottedMode;

  /// Whether triplet input mode is active.
  /// When active, the next 3 notes form a triplet group.
  bool _tripletMode = false;
  bool get tripletMode => _tripletMode;

  /// Counter tracking how many notes remain in the current triplet group.
  int _tripletRemaining = 0;

  /// Auto-incrementing triplet group ID.
  int _nextTripletGroupId = 1;

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
    _isInitialized = await _audioService.init();
    notifyListeners();
  }

  /// Set the active duration for future note input.
  void setDuration(NoteDuration duration) {
    _currentDuration = duration;

    if (_restMode && _selectionKind == null) {
      _insertRestAtCursor(duration: duration);
      _restMode = false;
    }

    notifyListeners();
  }

  /// Enter rest mode in input state or convert the selected note to a rest.
  void handleRestAction() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      final old = score.notes[_selectedNoteIndex!];
      score.replaceAt(_selectedNoteIndex!, old.asRest());
      notifyListeners();
      return;
    }

    if (_selectionKind != null) {
      return;
    }

    _restMode = !_restMode;
    notifyListeners();
  }

  /// Toggle dotted mode.
  void toggleDottedMode() {
    _dottedMode = !_dottedMode;
    notifyListeners();
  }

  /// Toggle triplet input mode.
  /// When activated, the next 3 notes will share a triplet group.
  void toggleTripletMode() {
    _tripletMode = !_tripletMode;
    if (!_tripletMode) {
      _tripletRemaining = 0;
    }
    notifyListeners();
  }

  int? _takeTripletGroupId() {
    int? tripletId;

    if (_tripletMode) {
      if (_tripletRemaining <= 0) {
        _tripletRemaining = 3;
        tripletId = _nextTripletGroupId++;
      } else {
        // Use the same group ID as the previous note in this group.
        tripletId = _nextTripletGroupId - 1;
      }
      _tripletRemaining--;
      if (_tripletRemaining <= 0) {
        _tripletMode = false;
      }
    }

    return tripletId;
  }

  void _insertAtCursor(Note note) {
    score.addNote(note, _cursorIndex);
    _cursorIndex++;
    _selectionKind = null;
    _selectedNoteIndex = null;

    if (!note.isRest) {
      _audioService.playNoteWithDuration(
        note.midi,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  void _insertRestAtCursor({NoteDuration? duration}) {
    _insertAtCursor(
      Note.rest(
        duration: duration ?? _currentDuration,
        isDotted: _dottedMode,
        tripletGroupId: _takeTripletGroupId(),
      ),
    );
  }

  /// Insert a pitched note at the cursor position.
  void insertPitchedNote(int rawMidi) {
    if (_restMode) {
      _restMode = false;
    }

    final midi = score.keySignature.applyToMidi(rawMidi);
    final note = Note(
      midi: midi,
      duration: _currentDuration,
      isDotted: _dottedMode,
      tripletGroupId: _takeTripletGroupId(),
    );

    _insertAtCursor(note);

    notifyListeners();
  }

  /// Select a note at the given index, or deselect (cursor at end) when null.
  void selectNote(int? index) {
    if (index != null && (index < 0 || index >= score.notes.length)) return;
    _restMode = false;

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
    _restMode = false;
    _selectionKind = SelectionKind.timeSig;
    _selectedNoteIndex = null;
    _cursorIndex = 0;
    notifyListeners();
  }

  /// Select the key signature element.
  void selectKeySig() {
    _restMode = false;
    _selectionKind = SelectionKind.keySig;
    _selectedNoteIndex = null;
    _cursorIndex = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Navigation (← / →)
  // ---------------------------------------------------------------------------

  /// Move selection one step to the left.
  /// Order: cursor(end) → note[n-1] → ... → note[0] → timeSig → keySig
  void moveSelectionLeft() {
    switch (_selectionKind) {
      case null:
        // At cursor/end — select last note if any, else timeSig.
        if (score.notes.isNotEmpty) {
          selectNote(score.notes.length - 1);
        } else {
          selectTimeSig();
        }
      case SelectionKind.note:
        final idx = _selectedNoteIndex ?? 0;
        if (idx > 0) {
          selectNote(idx - 1);
        } else {
          selectTimeSig();
        }
      case SelectionKind.timeSig:
        selectKeySig();
      case SelectionKind.keySig:
        break; // already leftmost
    }
  }

  /// Move selection one step to the right.
  /// Order: keySig → timeSig → note[0] → ... → note[n-1] → cursor(end)
  void moveSelectionRight() {
    switch (_selectionKind) {
      case SelectionKind.keySig:
        selectTimeSig();
      case SelectionKind.timeSig:
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
        cycleTimeSignature(direction);
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

  /// Toggle the dotted flag on the selected note.
  void toggleSelectedDotted() {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return;
    }
    final old = score.notes[_selectedNoteIndex!];
    score.replaceAt(_selectedNoteIndex!, old.copyWith(isDotted: !old.isDotted));
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

  /// Cycle through common time signatures.
  void cycleTimeSignature(int direction) {
    final current = (score.beatsPerMeasure, score.beatUnit);
    final idx = commonTimeSignatures.indexOf(current);
    final next = idx < 0
        ? 0
        : (idx + direction).clamp(0, commonTimeSignatures.length - 1);
    final (beats, unit) = commonTimeSignatures[next];
    setTimeSignature(beats, unit);
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
