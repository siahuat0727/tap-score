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
  static const int _defaultRestoreMidi = 60;
  static const double _epsilon = 0.001;

  final Score score = Score();
  final AudioService _audioService = AudioService();

  /// Index where the next note will be inserted.
  int _cursorIndex = 0;
  int get cursorIndex => _cursorIndex;

  /// What kind of element is selected. Null = cursor at end (input mode).
  SelectionKind? _selectionKind;
  SelectionKind? get selectionKind => _selectionKind;

  /// Currently selected note index (valid only when [_selectionKind] == note).
  int? _selectedNoteIndex;
  int? get selectedIndex =>
      _selectionKind == SelectionKind.note ? _selectedNoteIndex : null;

  Note? get selectedNote {
    final index = selectedIndex;
    if (index == null) return null;
    return score.notes[index];
  }

  /// Active duration for future note input.
  NoteDuration _currentDuration = NoteDuration.quarter;
  NoteDuration get currentDuration => _currentDuration;

  /// Whether rest mode is active for the next input.
  bool _restMode = false;
  bool get restMode => _restMode;

  /// Whether dotted mode is active for the next input.
  bool _dottedMode = false;
  bool get dottedMode => _dottedMode;

  /// Whether the next inserted pitched note should slur to its successor.
  bool _slurMode = false;
  bool get slurMode => _slurMode;

  /// Whether the next inserted input should become a complete triplet.
  bool _tripletMode = false;
  bool get tripletMode => _tripletMode;

  /// Auto-incrementing triplet group ID.
  int _nextTripletGroupId = 1;

  /// Selection-aware toolbar state.
  bool get timingControlsEnabled =>
      _selectionKind == null || _selectionKind == SelectionKind.note;
  NoteDuration get toolbarDuration =>
      selectedNote?.duration ?? _currentDuration;
  bool get toolbarShowsRestDurations => switch (_selectionKind) {
    SelectionKind.note => selectedNote?.isRest ?? false,
    null => _restMode,
    _ => false,
  };
  bool get toolbarRestSelected => switch (_selectionKind) {
    SelectionKind.note => selectedNote?.isRest ?? false,
    null => _restMode,
    _ => false,
  };
  bool get toolbarDottedSelected => switch (_selectionKind) {
    SelectionKind.note => selectedNote?.isDotted ?? false,
    null => _dottedMode,
    _ => false,
  };
  bool get toolbarSlurSelected => switch (_selectionKind) {
    SelectionKind.note => selectedNote?.slurToNext ?? false,
    null => _slurMode,
    _ => false,
  };
  bool get toolbarTripletSelected => switch (_selectionKind) {
    SelectionKind.note => _selectedValidTripletGroupIndices != null,
    null => _tripletMode,
    _ => false,
  };
  bool get slurButtonEnabled {
    if (_selectionKind == null) {
      return _cursorIndex >= score.notes.length ||
          !score.notes[_cursorIndex].isRest;
    }
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return false;
    }
    final selected = score.notes[_selectedNoteIndex!];
    if (selected.isRest) return false;
    if (_selectedNoteIndex! >= score.notes.length - 1) return true;
    return !score.notes[_selectedNoteIndex! + 1].isRest;
  }

  bool get tripletButtonEnabled {
    if (_selectionKind == null) return true;
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return false;
    }
    return _selectedValidTripletGroupIndices != null ||
        _canCreateTripletFromSelection(_selectedNoteIndex!);
  }

  bool get deleteButtonEnabled {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      return true;
    }
    return _selectionKind == null &&
        _cursorIndex == score.notes.length &&
        score.notes.isNotEmpty;
  }

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

  double get _measureDuration => score.beatsPerMeasure * (4.0 / score.beatUnit);

  List<int>? get _selectedValidTripletGroupIndices {
    final index = selectedIndex;
    if (index == null) return null;
    final groupId = score.notes[index].tripletGroupId;
    if (groupId == null) return null;
    final indices = _validTripletGroupIndices(groupId);
    if (indices == null || !indices.contains(index)) return null;
    return indices;
  }

  /// Set the active duration for future input, or edit the selected note/rest.
  void setDuration(NoteDuration duration) {
    if (!timingControlsEnabled) return;

    _currentDuration = duration;

    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      changeSelectedDuration(duration);
      return;
    }

    if (_restMode) {
      _insertRestAtCursor(duration: duration);
      _restMode = false;
    }

    notifyListeners();
  }

  /// Enter rest mode in input state or toggle the selected note/rest.
  void handleRestAction() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      final index = _selectedNoteIndex!;
      final old = score.notes[index];
      final updated = old.isRest
          ? old.asPitched(defaultMidi: _defaultRestoreMidi)
          : old.asRest();
      score.replaceAt(index, updated);
      _sanitizeSlursInRange(index - 1, index);
      _currentDuration = updated.duration;
      _dottedMode = updated.isDotted;

      if (!updated.isRest) {
        _audioService.playNoteWithDuration(
          updated.midi,
          duration: const Duration(milliseconds: 500),
        );
      }

      notifyListeners();
      return;
    }

    if (_selectionKind != null) {
      return;
    }

    _restMode = !_restMode;
    notifyListeners();
  }

  /// Toggle dotted mode for the next input or the selected note/triplet group.
  void toggleDottedMode() {
    if (!timingControlsEnabled) return;

    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      toggleSelectedDotted();
      return;
    }

    _dottedMode = !_dottedMode;
    notifyListeners();
  }

  /// Toggle slur input mode or edit the selected note.
  void toggleSlurMode() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      if (!slurButtonEnabled) return;
      final index = _selectedNoteIndex!;
      final note = score.notes[index];
      score.replaceAt(index, note.copyWith(slurToNext: !note.slurToNext));
      _sanitizeSlursInRange(index - 1, index);
      notifyListeners();
      return;
    }

    if (_selectionKind != null || !slurButtonEnabled) {
      return;
    }

    _slurMode = !_slurMode;
    notifyListeners();
  }

  /// Toggle triplet input mode or edit the selected note group.
  void toggleTripletMode() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      final selectedTriplet = _selectedValidTripletGroupIndices;
      if (selectedTriplet != null) {
        for (final index in selectedTriplet) {
          final note = score.notes[index];
          score.replaceAt(
            index,
            note.copyWith(tripletGroupId: () => null, slurToNext: false),
          );
        }
        _sanitizeSlursInRange(selectedTriplet.first - 1, selectedTriplet.last);
        notifyListeners();
        return;
      }

      if (!tripletButtonEnabled) {
        return;
      }

      _createTripletFromSelection(_selectedNoteIndex!);
      notifyListeners();
      return;
    }

    if (_selectionKind != null) {
      return;
    }

    _tripletMode = !_tripletMode;
    notifyListeners();
  }

  void _insertNotesAtCursor(List<Note> notes) {
    final startIndex = _cursorIndex;
    for (final note in notes) {
      score.addNote(note, _cursorIndex);
      _cursorIndex++;
    }
    _sanitizeSlursInRange(startIndex - 1, _cursorIndex - 1);

    _selectionKind = null;
    _selectedNoteIndex = null;

    Note? soundedNote;
    for (final note in notes) {
      if (!note.isRest) {
        soundedNote = note;
        break;
      }
    }
    if (soundedNote != null) {
      _audioService.playNoteWithDuration(
        soundedNote.midi,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  List<Note> _expandForPendingTriplet(Note prototype) {
    if (!_tripletMode) {
      return [prototype];
    }

    final tripletGroupId = _nextTripletGroupId++;
    _tripletMode = false;

    return List<Note>.generate(3, (index) {
      return prototype.copyWith(
        tripletGroupId: () => tripletGroupId,
        slurToNext: prototype.slurToNext && index == 2,
      );
    }, growable: false);
  }

  void _insertRestAtCursor({NoteDuration? duration}) {
    final prototype = Note.rest(
      duration: duration ?? _currentDuration,
      isDotted: _dottedMode,
    );
    _insertNotesAtCursor(_expandForPendingTriplet(prototype));
  }

  /// Insert a pitched note at the cursor position.
  void insertPitchedNote(int rawMidi) {
    if (_restMode) {
      _restMode = false;
    }

    final midi = score.keySignature.applyToMidi(rawMidi);
    final prototype = Note(
      midi: midi,
      duration: _currentDuration,
      isDotted: _dottedMode,
      slurToNext: _slurMode,
    );
    _slurMode = false;

    _insertNotesAtCursor(_expandForPendingTriplet(prototype));
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
        break;
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
          selectNote(null);
        }
      case SelectionKind.note:
        final idx = _selectedNoteIndex ?? 0;
        if (idx < score.notes.length - 1) {
          selectNote(idx + 1);
        } else {
          selectNote(null);
        }
      case null:
        break;
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
        break;
    }
  }

  /// Move the selected note by one diatonic step.
  void _diatonicStepSelected(int direction) {
    if (_selectedNoteIndex == null) return;
    final note = score.notes[_selectedNoteIndex!];
    if (note.isRest) return;
    final newMidi = score.keySignature.diatonicStep(note.midi, direction);
    if (newMidi == note.midi) return;
    score.replaceAt(
      _selectedNoteIndex!,
      note.copyWith(midi: newMidi, sourceMidi: () => null),
    );
    _audioService.playNoteWithDuration(
      newMidi,
      duration: const Duration(milliseconds: 500),
    );
    notifyListeners();
  }

  /// Delete the currently selected note, or the last note in end-input mode.
  void deleteSelected() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      _deleteNoteAtIndex(_selectedNoteIndex!, keepSelection: true);
      notifyListeners();
      return;
    }

    if (_selectionKind == null &&
        _cursorIndex == score.notes.length &&
        score.notes.isNotEmpty) {
      _deleteNoteAtIndex(score.notes.length - 1, keepSelection: false);
      notifyListeners();
    }
  }

  void _deleteNoteAtIndex(int removedIndex, {required bool keepSelection}) {
    final previousIndex = removedIndex - 1;
    final tripletGroupId = score.notes[removedIndex].tripletGroupId;
    final tripletGroup = tripletGroupId == null
        ? null
        : _validTripletGroupIndices(tripletGroupId);
    score.removeAt(removedIndex);

    if (tripletGroup != null) {
      for (final originalIndex in tripletGroup.where(
        (i) => i != removedIndex,
      )) {
        final shiftedIndex = originalIndex > removedIndex
            ? originalIndex - 1
            : originalIndex;
        if (shiftedIndex >= 0 && shiftedIndex < score.notes.length) {
          final note = score.notes[shiftedIndex];
          score.replaceAt(
            shiftedIndex,
            note.copyWith(tripletGroupId: () => null, slurToNext: false),
          );
        }
      }
    }
    if (previousIndex >= 0 && previousIndex < score.notes.length) {
      final previous = score.notes[previousIndex];
      if (previous.slurToNext) {
        score.replaceAt(previousIndex, previous.copyWith(slurToNext: false));
      }
    }
    _sanitizeSlursInRange(removedIndex - 1, removedIndex);

    if (_cursorIndex > removedIndex) {
      _cursorIndex--;
    }

    if (!keepSelection) {
      _selectionKind = null;
      _selectedNoteIndex = null;
      _cursorIndex = score.notes.length;
      return;
    }

    if (score.notes.isEmpty) {
      _selectionKind = null;
      _selectedNoteIndex = null;
      _cursorIndex = 0;
      return;
    }

    _selectionKind = SelectionKind.note;
    _selectedNoteIndex = removedIndex >= score.notes.length
        ? score.notes.length - 1
        : removedIndex;
    _cursorIndex = _selectedNoteIndex! + 1;
  }

  /// Change the pitch of the selected note.
  void changeSelectedPitch(int midi) {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return;
    }
    final old = score.notes[_selectedNoteIndex!];
    score.replaceAt(
      _selectedNoteIndex!,
      old.copyWith(midi: midi, sourceMidi: () => null),
    );

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

    _currentDuration = duration;
    _applyDurationOrDotToSelectedGroup(
      (note) => note.copyWith(duration: duration),
    );
    notifyListeners();
  }

  /// Toggle the dotted flag on the selected note.
  void toggleSelectedDotted() {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return;
    }

    final nextValue = !score.notes[_selectedNoteIndex!].isDotted;
    _dottedMode = nextValue;
    _applyDurationOrDotToSelectedGroup(
      (note) => note.copyWith(isDotted: nextValue),
    );
    notifyListeners();
  }

  void _applyDurationOrDotToSelectedGroup(Note Function(Note note) transform) {
    final selectedTriplet = _selectedValidTripletGroupIndices;
    if (selectedTriplet != null) {
      for (final index in selectedTriplet) {
        score.replaceAt(index, transform(score.notes[index]));
      }
      return;
    }

    final index = _selectedNoteIndex;
    if (index == null) return;
    score.replaceAt(index, transform(score.notes[index]));
  }

  void _sanitizeSlursInRange(int start, int end) {
    if (score.notes.isEmpty) return;
    final lower = start.clamp(0, score.notes.length - 1);
    final upper = end.clamp(0, score.notes.length - 1);
    if (lower > upper) return;
    for (var index = lower; index <= upper; index++) {
      _sanitizeSlurAt(index);
    }
  }

  void _sanitizeSlurAt(int index) {
    if (index < 0 || index >= score.notes.length) return;
    final note = score.notes[index];
    final hasNext = index + 1 < score.notes.length;
    final nextIsRest = hasNext && score.notes[index + 1].isRest;
    if (note.slurToNext && (note.isRest || nextIsRest)) {
      score.replaceAt(index, note.copyWith(slurToNext: false));
    }
  }

  int? _nextTripletStartIndex(int selectedIndex) {
    if (selectedIndex == score.notes.length - 1) {
      return selectedIndex;
    }

    if (selectedIndex + 2 >= score.notes.length) {
      return null;
    }

    return selectedIndex;
  }

  bool _canCreateTripletFromSelection(int selectedIndex) {
    final startIndex = _nextTripletStartIndex(selectedIndex);
    if (startIndex == null) return false;

    final selected = score.notes[selectedIndex];
    if (selected.tripletGroupId != null) return false;

    if (selectedIndex == score.notes.length - 1) {
      return _tripletFitsAt(startIndex, selected.writtenBeats);
    }

    final candidates = score.notes.sublist(startIndex, startIndex + 3);
    final first = candidates.first;

    if (candidates.any((note) => note.tripletGroupId != null)) {
      return false;
    }

    if (candidates.any(
      (note) =>
          note.duration != first.duration || note.isDotted != first.isDotted,
    )) {
      return false;
    }

    return _tripletFitsAt(startIndex, first.writtenBeats);
  }

  bool _tripletFitsAt(int startIndex, double writtenBeats) {
    final beatsBefore = _beatsBeforeIndex(startIndex);
    final beatInMeasure = beatsBefore % _measureDuration;
    final tripletBeats = writtenBeats * 2.0;
    return beatInMeasure + tripletBeats <= _measureDuration + _epsilon;
  }

  double _beatsBeforeIndex(int index) {
    var beats = 0.0;
    for (var i = 0; i < index; i++) {
      beats += score.notes[i].effectiveBeats;
    }
    return beats;
  }

  List<int>? _validTripletGroupIndices(int groupId) {
    final indices = <int>[];

    for (var i = 0; i < score.notes.length; i++) {
      if (score.notes[i].tripletGroupId == groupId) {
        indices.add(i);
      }
    }

    if (indices.length != 3) return null;

    for (var i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) return null;
    }

    final first = score.notes[indices.first];
    if (indices.any((index) {
      final note = score.notes[index];
      return note.duration != first.duration || note.isDotted != first.isDotted;
    })) {
      return null;
    }

    return indices;
  }

  void _createTripletFromSelection(int selectedIndex) {
    final source = score.notes[selectedIndex];
    final tripletGroupId = _nextTripletGroupId++;

    score.replaceAt(
      selectedIndex,
      source.copyWith(tripletGroupId: () => tripletGroupId, slurToNext: false),
    );

    if (selectedIndex == score.notes.length - 1) {
      final cloneA = source.copyWith(
        tripletGroupId: () => tripletGroupId,
        slurToNext: false,
      );
      final cloneB = source.copyWith(
        tripletGroupId: () => tripletGroupId,
        slurToNext: false,
      );
      score.addNote(cloneA, selectedIndex + 1);
      score.addNote(cloneB, selectedIndex + 2);
      _sanitizeSlursInRange(selectedIndex - 1, selectedIndex + 2);
      return;
    }

    for (var i = selectedIndex + 1; i <= selectedIndex + 2; i++) {
      final note = score.notes[i];
      score.replaceAt(
        i,
        note.copyWith(tripletGroupId: () => tripletGroupId, slurToNext: false),
      );
    }
    _sanitizeSlursInRange(selectedIndex - 1, selectedIndex + 2);
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
