import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/input/editor_shortcuts.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/key_signature.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/services/audio_service.dart';
import 'package:tap_score/state/editable_score_session.dart';
import 'package:tap_score/state/editor_controller.dart';
import 'package:tap_score/state/playback_controller.dart';

// ignore: library_private_types_in_public_api
_EditorHarness buildEditorHarness() {
  final session = EditableScoreSession();
  final playback = _PreviewPlaybackController(session: session);
  final editor = EditorController(session: session, notePreview: playback);
  return _EditorHarness(session: session, playback: playback, editor: editor);
}

class _EditorHarness {
  const _EditorHarness({
    required this.session,
    required this.playback,
    required this.editor,
  });

  final EditableScoreSession session;
  final _PreviewPlaybackController playback;
  final EditorController editor;

  void dispose() {
    editor.dispose();
    playback.dispose();
    session.dispose();
  }
}

class _PreviewPlaybackController extends PlaybackController {
  _PreviewPlaybackController({required super.session})
    : super(audioService: AudioService(testMode: true));

  final List<int> previewedMidis = [];

  @override
  void previewNote(
    int midi, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    previewedMidis.add(midi);
  }
}

void main() {
  test('thirty-second note duration reports the expected beats', () {
    expect(NoteDuration.thirtySecond.beats, 0.125);
  });

  test('selectNote throws for invalid note indexes', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);

    expect(() => harness.editor.selectNote(0), throwsA(isA<RangeError>()));
  });

  test('score changes notify session and editor and mark unsaved', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);

    var sessionNotifications = 0;
    var editorNotifications = 0;
    harness.session.addListener(() {
      sessionNotifications += 1;
    });
    harness.editor.addListener(() {
      editorNotifications += 1;
    });

    expect(harness.session.hasUnsavedChanges, isFalse);

    harness.editor.insertPitchedNote(60);

    expect(sessionNotifications, 1);
    expect(editorNotifications, 1);
    expect(harness.session.hasUnsavedChanges, isTrue);
  });

  test('editor-only state changes notify editor without dirtying session', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);

    var sessionNotifications = 0;
    var editorNotifications = 0;
    harness.session.addListener(() {
      sessionNotifications += 1;
    });
    harness.editor.addListener(() {
      editorNotifications += 1;
    });

    expect(harness.session.hasUnsavedChanges, isFalse);

    harness.editor.toggleTripletMode();

    expect(sessionNotifications, 0);
    expect(editorNotifications, 1);
    expect(harness.session.hasUnsavedChanges, isFalse);
  });

  test('score replacement resets editor selection and input state', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final editor = harness.editor;
    final session = harness.session;

    editor.setDuration(NoteDuration.half);
    editor.toggleDottedMode();
    editor.toggleSlurMode();
    editor.toggleTripletMode();
    session.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    editor.selectNote(1);

    session.replaceScore(
      Score(notes: const [Note(midi: 67, duration: NoteDuration.quarter)]),
    );

    expect(editor.selectionKind, isNull);
    expect(editor.selectedIndex, isNull);
    expect(editor.selectedNote, isNull);
    expect(editor.cursorIndex, 1);
    expect(editor.currentDuration, NoteDuration.quarter);
    expect(editor.dottedMode, isFalse);
    expect(editor.slurMode, isFalse);
    expect(editor.tripletMode, isFalse);
  });

  test('inserting a pitched note previews that midi', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);

    harness.editor.insertPitchedNote(60);

    expect(harness.playback.previewedMidis, [60]);
  });

  test('selecting a pitched note previews that midi', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    harness.session.score.addNote(
      const Note(midi: 62, duration: NoteDuration.quarter),
    );

    harness.editor.selectNote(0);

    expect(harness.playback.previewedMidis, [62]);
  });

  test('changing selected pitch previews the new midi', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    harness.session.score.addNote(
      const Note(midi: 62, duration: NoteDuration.quarter),
    );
    harness.editor.selectNote(0);
    harness.playback.previewedMidis.clear();

    harness.editor.changeSelectedPitch(65);

    expect(harness.playback.previewedMidis, [65]);
  });

  test('rest mode inserts a rest when duration is chosen', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.handleRestAction();
    expect(notifier.restMode, isTrue);

    notifier.setDuration(NoteDuration.half);

    expect(notifier.restMode, isFalse);
    expect(notifier.currentDuration, NoteDuration.half);
    expect(score.notes, hasLength(1));
    expect(score.notes.single.isRest, isTrue);
    expect(score.notes.single.duration, NoteDuration.half);
    expect(notifier.cursorIndex, 1);
  });

  test('rest action converts selected note to a rest preserving timing', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.addNote(
      const Note(
        midi: 60,
        duration: NoteDuration.eighth,
        isDotted: true,
        tripletGroupId: 7,
      ),
    );
    notifier.selectNote(0);

    notifier.handleRestAction();

    final note = score.notes.single;
    expect(note.isRest, isTrue);
    expect(note.duration, NoteDuration.eighth);
    expect(note.isDotted, isTrue);
    expect(note.tripletGroupId, 7);
    expect(notifier.selectedIndex, 0);
  });

  test(
    'changing duration while a note is selected edits the selected note',
    () {
      final harness = buildEditorHarness();
      addTearDown(harness.dispose);
      final notifier = harness.editor;
      final score = harness.session.score;

      score.addNote(const Note(midi: 60, duration: NoteDuration.quarter));
      notifier.selectNote(0);
      notifier.setDuration(NoteDuration.half);

      expect(score.notes.single.duration, NoteDuration.half);
      expect(notifier.currentDuration, NoteDuration.half);
      expect(notifier.selectedIndex, 0);
    },
  );

  test('rest action toggles selected rest back to its stored pitch', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.addNote(const Note(midi: 64, duration: NoteDuration.quarter));
    notifier.selectNote(0);

    notifier.handleRestAction();
    expect(score.notes.single.isRest, isTrue);
    expect(score.notes.single.sourceMidi, 64);

    notifier.handleRestAction();
    final restored = score.notes.single;
    expect(restored.isRest, isFalse);
    expect(restored.midi, 64);
    expect(restored.tripletGroupId, isNull);
  });

  test('rest without stored pitch restores to the active clef default', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.addNote(const Note.rest(duration: NoteDuration.eighth));
    notifier.selectNote(0);
    notifier.handleRestAction();

    final restored = score.notes.single;
    expect(restored.isRest, isFalse);
    expect(restored.midi, 60);
    expect(restored.duration, NoteDuration.eighth);
  });

  test('bass clef restores rests to C3 by default', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.setClef(Clef.bass);
    score.addNote(const Note.rest(duration: NoteDuration.eighth));
    notifier.selectNote(0);
    notifier.handleRestAction();

    expect(score.notes.single.midi, 48);
  });

  test('toggle dotted mode edits the selected triplet group together', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.eighth, tripletGroupId: 4),
      const Note(midi: 62, duration: NoteDuration.eighth, tripletGroupId: 4),
      const Note(midi: 64, duration: NoteDuration.eighth, tripletGroupId: 4),
    ]);
    notifier.selectNote(1);

    notifier.toggleDottedMode();

    for (final note in score.notes) {
      expect(note.isDotted, isTrue);
      expect(note.tripletGroupId, 4);
    }
  });

  test('triplet input inserts three identical notes at once', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.toggleTripletMode();
    notifier.insertPitchedNote(60);

    expect(notifier.tripletMode, isFalse);
    expect(score.notes, hasLength(3));
    expect(score.notes.map((note) => note.midi), [60, 60, 60]);
    expect(score.notes.map((note) => note.tripletGroupId).toSet().length, 1);
    expect(score.notes.first.tripletGroupId, isNotNull);
  });

  test('key-signature-aware input applies the current key signature', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.setKeySignature(KeySignature.gMajor);

    expect(notifier.resolveInputMidi(65), 66);

    notifier.insertPitchedNote(notifier.resolveInputMidi(65));
    expect(score.notes.single.midi, 66);
  });

  test('chromatic input bypasses the current key signature', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.setKeySignature(KeySignature.gMajor);
    notifier.toggleKeyboardInputMode();

    expect(notifier.keyboardInputMode, KeyboardInputMode.chromatic);
    expect(notifier.resolveInputMidi(65), 65);

    notifier.insertPitchedNote(notifier.resolveInputMidi(65));
    expect(score.notes.single.midi, 65);
  });

  test('keyboard mapping shift clamps to the supported visible range', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;

    notifier.shiftKeyboardMapping(-1);
    expect(notifier.keyboardOctaveShift, -1);
    expect(notifier.canShiftKeyboardMappingDown, isFalse);

    notifier.shiftKeyboardMapping(-1);
    expect(notifier.keyboardOctaveShift, -1);

    notifier.shiftKeyboardMapping(2);
    expect(notifier.keyboardOctaveShift, 1);
    expect(notifier.canShiftKeyboardMappingUp, isFalse);
  });

  test(
    'bass clef allows two upward keyboard shifts within the visible range',
    () {
      final harness = buildEditorHarness();
      addTearDown(harness.dispose);
      final notifier = harness.editor;

      notifier.setClef(Clef.bass);
      expect(notifier.keyboardOctaveShift, 0);
      expect(notifier.canShiftKeyboardMappingDown, isFalse);
      expect(notifier.canShiftKeyboardMappingUp, isTrue);

      notifier.shiftKeyboardMapping(1);
      expect(notifier.keyboardOctaveShift, 1);
      expect(notifier.canShiftKeyboardMappingUp, isTrue);

      notifier.shiftKeyboardMapping(1);
      expect(notifier.keyboardOctaveShift, 2);
      expect(notifier.canShiftKeyboardMappingUp, isFalse);

      notifier.shiftKeyboardMapping(1);
      expect(notifier.keyboardOctaveShift, 2);
    },
  );

  test('editor shortcuts route through shared keyboard input state', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.handleEditorShortcut(const EditorShortcutIntent.shiftDown());
    notifier.handleEditorShortcut(const EditorShortcutIntent.toggleInputMode());
    notifier.handleEditorShortcut(const EditorShortcutIntent.insertPitch(60));

    expect(notifier.keyboardOctaveShift, -1);
    expect(notifier.keyboardInputMode, KeyboardInputMode.chromatic);
    expect(score.notes.single.midi, 60);
  });

  test('setClef updates score metadata without changing existing notes', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;
    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 43, duration: NoteDuration.half),
    ]);

    notifier.setClef(Clef.bass);

    expect(score.clef, Clef.bass);
    expect(score.notes.map((note) => note.midi).toList(), [60, 43]);
  });

  test('setClef clamps keyboard shift into the new clef range', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;

    notifier.shiftKeyboardMapping(-1);
    expect(notifier.keyboardOctaveShift, -1);

    notifier.setClef(Clef.bass);
    expect(notifier.keyboardOctaveShift, 0);

    notifier.shiftKeyboardMapping(2);
    expect(notifier.keyboardOctaveShift, 2);

    notifier.setClef(Clef.treble);
    expect(notifier.keyboardOctaveShift, 1);
  });

  test(
    'piano taps ignore keyboard octave shift and insert real white keys',
    () {
      final harness = buildEditorHarness();
      addTearDown(harness.dispose);
      final notifier = harness.editor;
      final score = harness.session.score;

      notifier.shiftKeyboardMapping(-1);
      notifier.handlePianoTap(45);

      expect(notifier.keyboardOctaveShift, -1);
      expect(score.notes.single.midi, 45);
    },
  );

  test('key-signature-aware piano taps reject black keys', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.handlePianoTap(61);

    expect(score.notes, isEmpty);
  });

  test('key-signature-aware piano taps apply key signature to white keys', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.setKeySignature(KeySignature.gMajor);
    notifier.handlePianoTap(65);

    expect(score.notes.single.midi, 66);
  });

  test(
    'chromatic piano taps allow black keys without key-signature changes',
    () {
      final harness = buildEditorHarness();
      addTearDown(harness.dispose);
      final notifier = harness.editor;
      final score = harness.session.score;

      notifier.setKeySignature(KeySignature.gMajor);
      notifier.toggleKeyboardInputMode();
      notifier.handlePianoTap(61);

      expect(score.notes.single.midi, 61);
    },
  );

  test('setKeySignature remaps all existing pitched notes', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.notes.addAll([
      const Note(midi: 65, duration: NoteDuration.quarter),
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note.rest(duration: NoteDuration.quarter),
    ]);

    notifier.setKeySignature(KeySignature.dMajor);

    expect(score.notes[0].midi, 66);
    expect(score.notes[1].midi, 61);
    expect(score.notes[2].isRest, isTrue);
  });

  test('setKeySignature remaps notes from the previous key intent', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.notes.addAll([
      const Note(midi: 66, duration: NoteDuration.quarter),
      const Note(midi: 60, duration: NoteDuration.quarter),
    ]);
    notifier.setKeySignature(KeySignature.gMajor);

    notifier.setKeySignature(KeySignature.dMajor);

    expect(score.notes[0].midi, 66);
    expect(score.notes[1].midi, 61);
  });

  test('triplet input inserts three identical rests at once', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.toggleTripletMode();
    notifier.handleRestAction();
    notifier.setDuration(NoteDuration.eighth);

    expect(notifier.tripletMode, isFalse);
    expect(notifier.restMode, isFalse);
    expect(score.notes, hasLength(3));
    expect(score.notes.every((note) => note.isRest), isTrue);
    expect(score.notes.map((note) => note.tripletGroupId).toSet().length, 1);
  });

  test('triplet action clones the last selected note into a full triplet', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.addNote(const Note(midi: 67, duration: NoteDuration.quarter));
    notifier.selectNote(0);

    expect(notifier.tripletButtonEnabled, isTrue);

    notifier.toggleTripletMode();

    expect(score.notes, hasLength(3));
    expect(notifier.selectedIndex, 0);
    expect(notifier.toolbarTripletSelected, isTrue);
    expect(score.notes.map((note) => note.midi), [67, 67, 67]);
    expect(score.notes.map((note) => note.tripletGroupId).toSet().length, 1);
  });

  test('triplet action converts and removes a valid three-note group', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
      const Note(midi: 64, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    expect(notifier.tripletButtonEnabled, isTrue);
    notifier.toggleTripletMode();

    final groupId = score.notes.first.tripletGroupId;
    expect(groupId, isNotNull);
    expect(score.notes.every((note) => note.tripletGroupId == groupId), isTrue);

    notifier.toggleTripletMode();
    expect(score.notes.every((note) => note.tripletGroupId == null), isTrue);
  });

  test('triplet action is disabled when next notes do not match timing', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.half),
      const Note(midi: 64, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    expect(notifier.tripletButtonEnabled, isFalse);
    notifier.toggleTripletMode();

    expect(score.notes.every((note) => note.tripletGroupId == null), isTrue);
  });

  test(
    'triplet action is disabled when cloned triplet would overflow measure',
    () {
      final harness = buildEditorHarness();
      addTearDown(harness.dispose);
      final notifier = harness.editor;
      final score = harness.session.score;

      notifier.setTimeSignature(3, 4);
      score.notes.addAll([
        const Note(midi: 60, duration: NoteDuration.quarter),
        const Note(midi: 62, duration: NoteDuration.quarter),
        const Note(midi: 64, duration: NoteDuration.quarter),
      ]);
      notifier.selectNote(2);

      expect(notifier.tripletButtonEnabled, isFalse);
      notifier.toggleTripletMode();

      expect(score.notes, hasLength(3));
      expect(score.notes.every((note) => note.tripletGroupId == null), isTrue);
    },
  );

  test('slur input applies to the next pitched note and resets', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;

    notifier.toggleSlurMode();
    expect(notifier.slurMode, isTrue);

    notifier.insertPitchedNote(60);

    expect(notifier.slurMode, isFalse);
    expect(score.notes.single.slurToNext, isTrue);
  });

  test('selected pitched note toggles slur to next', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;
    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    expect(notifier.slurButtonEnabled, isTrue);
    notifier.toggleSlurMode();
    expect(score.notes.first.slurToNext, isTrue);

    notifier.toggleSlurMode();
    expect(score.notes.first.slurToNext, isFalse);
  });

  test('changing the last note of a triplet adds a tied continuation', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;
    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.eighth, tripletGroupId: 4),
      const Note(midi: 62, duration: NoteDuration.eighth, tripletGroupId: 4),
      const Note(midi: 64, duration: NoteDuration.eighth, tripletGroupId: 4),
    ]);
    notifier.selectNote(2);

    notifier.setDuration(NoteDuration.quarter);

    expect(score.notes, hasLength(4));
    expect(score.notes.take(3).map((note) => note.tripletGroupId).toSet(), {4});
    expect(score.notes.take(3).map((note) => note.duration).toList(), [
      NoteDuration.eighth,
      NoteDuration.eighth,
      NoteDuration.eighth,
    ]);
    expect(score.notes[2].slurToNext, isTrue);
    expect(score.notes[3].tripletGroupId, isNull);
    expect(score.notes[3].midi, 64);
    expect(score.notes[3].duration, NoteDuration.quarter);
    expect(notifier.selectedIndex, 3);
  });

  test('changing a non-final triplet note duration is unsupported', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;
    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.eighth, tripletGroupId: 4),
      const Note(midi: 62, duration: NoteDuration.eighth, tripletGroupId: 4),
      const Note(midi: 64, duration: NoteDuration.eighth, tripletGroupId: 4),
    ]);
    notifier.selectNote(1);

    expect(notifier.durationButtonsEnabled, isFalse);
    notifier.setDuration(NoteDuration.quarter);

    expect(score.notes, hasLength(3));
    expect(score.notes.map((note) => note.duration).toList(), [
      NoteDuration.eighth,
      NoteDuration.eighth,
      NoteDuration.eighth,
    ]);
    expect(notifier.selectedIndex, 1);
  });

  test('rest cannot be marked with a slur', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;
    score.notes.addAll([
      const Note.rest(duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    expect(notifier.slurButtonEnabled, isFalse);
    notifier.toggleSlurMode();

    expect(score.notes.first.slurToNext, isFalse);
  });

  test('delete removes the last note in end-input mode', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;
    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(null);

    expect(notifier.deleteButtonEnabled, isTrue);
    notifier.deleteSelected();

    expect(score.notes, hasLength(1));
    expect(score.notes.single.midi, 60);
    expect(notifier.selectionKind, isNull);
    expect(notifier.cursorIndex, 1);
  });

  test('deleting a slurred target clears the previous slur', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;
    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter, slurToNext: true),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(1);

    notifier.deleteSelected();

    expect(score.notes, hasLength(1));
    expect(score.notes.single.slurToNext, isFalse);
  });

  test('turning a slurred note into a rest clears adjacent slurs', () {
    final harness = buildEditorHarness();
    addTearDown(harness.dispose);
    final notifier = harness.editor;
    final score = harness.session.score;
    score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter, slurToNext: true),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(1);

    notifier.handleRestAction();

    expect(score.notes[0].slurToNext, isFalse);
    expect(score.notes[1].isRest, isTrue);
  });
}
