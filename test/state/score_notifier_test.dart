import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/input/editor_shortcuts.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/key_signature.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/services/audio_service.dart';
import 'package:tap_score/state/score_notifier.dart';

void main() {
  test('thirty-second note duration reports the expected beats', () {
    expect(NoteDuration.thirtySecond.beats, 0.125);
  });

  test('rest mode inserts a rest when duration is chosen', () {
    final notifier = ScoreNotifier();

    notifier.handleRestAction();
    expect(notifier.restMode, isTrue);

    notifier.setDuration(NoteDuration.half);

    expect(notifier.restMode, isFalse);
    expect(notifier.currentDuration, NoteDuration.half);
    expect(notifier.score.notes, hasLength(1));
    expect(notifier.score.notes.single.isRest, isTrue);
    expect(notifier.score.notes.single.duration, NoteDuration.half);
    expect(notifier.cursorIndex, 1);
  });

  test('rest action converts selected note to a rest preserving timing', () {
    final notifier = ScoreNotifier();

    notifier.score.addNote(
      const Note(
        midi: 60,
        duration: NoteDuration.eighth,
        isDotted: true,
        tripletGroupId: 7,
      ),
    );
    notifier.selectNote(0);

    notifier.handleRestAction();

    final note = notifier.score.notes.single;
    expect(note.isRest, isTrue);
    expect(note.duration, NoteDuration.eighth);
    expect(note.isDotted, isTrue);
    expect(note.tripletGroupId, 7);
    expect(notifier.selectedIndex, 0);
  });

  test(
    'changing duration while a note is selected edits the selected note',
    () {
      final notifier = ScoreNotifier();

      notifier.score.addNote(
        const Note(midi: 60, duration: NoteDuration.quarter),
      );
      notifier.selectNote(0);
      notifier.setDuration(NoteDuration.half);

      expect(notifier.score.notes.single.duration, NoteDuration.half);
      expect(notifier.currentDuration, NoteDuration.half);
      expect(notifier.selectedIndex, 0);
    },
  );

  test('rest action toggles selected rest back to its stored pitch', () {
    final notifier = ScoreNotifier();

    notifier.score.addNote(
      const Note(midi: 64, duration: NoteDuration.quarter),
    );
    notifier.selectNote(0);

    notifier.handleRestAction();
    expect(notifier.score.notes.single.isRest, isTrue);
    expect(notifier.score.notes.single.sourceMidi, 64);

    notifier.handleRestAction();
    final restored = notifier.score.notes.single;
    expect(restored.isRest, isFalse);
    expect(restored.midi, 64);
    expect(restored.tripletGroupId, isNull);
  });

  test('rest without stored pitch restores to C4', () {
    final notifier = ScoreNotifier();

    notifier.score.addNote(const Note.rest(duration: NoteDuration.eighth));
    notifier.selectNote(0);
    notifier.handleRestAction();

    final restored = notifier.score.notes.single;
    expect(restored.isRest, isFalse);
    expect(restored.midi, 60);
    expect(restored.duration, NoteDuration.eighth);
  });

  test('toggle dotted mode edits the selected triplet group together', () {
    final notifier = ScoreNotifier();

    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.eighth, tripletGroupId: 4),
      const Note(midi: 62, duration: NoteDuration.eighth, tripletGroupId: 4),
      const Note(midi: 64, duration: NoteDuration.eighth, tripletGroupId: 4),
    ]);
    notifier.selectNote(1);

    notifier.toggleDottedMode();

    for (final note in notifier.score.notes) {
      expect(note.isDotted, isTrue);
      expect(note.tripletGroupId, 4);
    }
  });

  test('triplet input inserts three identical notes at once', () {
    final notifier = ScoreNotifier();

    notifier.toggleTripletMode();
    notifier.insertPitchedNote(60);

    expect(notifier.tripletMode, isFalse);
    expect(notifier.score.notes, hasLength(3));
    expect(notifier.score.notes.map((note) => note.midi), [60, 60, 60]);
    expect(
      notifier.score.notes.map((note) => note.tripletGroupId).toSet().length,
      1,
    );
    expect(notifier.score.notes.first.tripletGroupId, isNotNull);
  });

  test('key-signature-aware input applies the current key signature', () {
    final notifier = ScoreNotifier();

    notifier.setKeySignature(KeySignature.gMajor);

    expect(notifier.resolveInputMidi(65), 66);

    notifier.insertPitchedNote(notifier.resolveInputMidi(65));
    expect(notifier.score.notes.single.midi, 66);
  });

  test('chromatic input bypasses the current key signature', () {
    final notifier = ScoreNotifier();

    notifier.setKeySignature(KeySignature.gMajor);
    notifier.toggleKeyboardInputMode();

    expect(notifier.keyboardInputMode, KeyboardInputMode.chromatic);
    expect(notifier.resolveInputMidi(65), 65);

    notifier.insertPitchedNote(notifier.resolveInputMidi(65));
    expect(notifier.score.notes.single.midi, 65);
  });

  test('keyboard mapping shift clamps to the supported visible range', () {
    final notifier = ScoreNotifier();

    notifier.shiftKeyboardMapping(-1);
    expect(notifier.keyboardOctaveShift, -1);
    expect(notifier.canShiftKeyboardMappingDown, isFalse);

    notifier.shiftKeyboardMapping(-1);
    expect(notifier.keyboardOctaveShift, -1);

    notifier.shiftKeyboardMapping(2);
    expect(notifier.keyboardOctaveShift, 1);
    expect(notifier.canShiftKeyboardMappingUp, isFalse);
  });

  test('editor shortcuts route through shared keyboard input state', () {
    final notifier = ScoreNotifier();

    notifier.handleEditorShortcut(const EditorShortcutIntent.shiftDown());
    notifier.handleEditorShortcut(const EditorShortcutIntent.toggleInputMode());
    notifier.handleEditorShortcut(const EditorShortcutIntent.insertPitch(60));

    expect(notifier.keyboardOctaveShift, -1);
    expect(notifier.keyboardInputMode, KeyboardInputMode.chromatic);
    expect(notifier.score.notes.single.midi, 60);
  });

  test(
    'piano taps ignore keyboard octave shift and insert real white keys',
    () {
      final notifier = ScoreNotifier();

      notifier.shiftKeyboardMapping(-1);
      notifier.handlePianoTap(45);

      expect(notifier.keyboardOctaveShift, -1);
      expect(notifier.score.notes.single.midi, 45);
    },
  );

  test('key-signature-aware piano taps reject black keys', () {
    final notifier = ScoreNotifier();

    notifier.handlePianoTap(61);

    expect(notifier.score.notes, isEmpty);
  });

  test('key-signature-aware piano taps apply key signature to white keys', () {
    final notifier = ScoreNotifier();

    notifier.setKeySignature(KeySignature.gMajor);
    notifier.handlePianoTap(65);

    expect(notifier.score.notes.single.midi, 66);
  });

  test(
    'chromatic piano taps allow black keys without key-signature changes',
    () {
      final notifier = ScoreNotifier();

      notifier.setKeySignature(KeySignature.gMajor);
      notifier.toggleKeyboardInputMode();
      notifier.handlePianoTap(61);

      expect(notifier.score.notes.single.midi, 61);
    },
  );

  test('setKeySignature remaps all existing pitched notes', () {
    final notifier = ScoreNotifier();

    notifier.score.notes.addAll([
      const Note(midi: 65, duration: NoteDuration.quarter),
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note.rest(duration: NoteDuration.quarter),
    ]);

    notifier.setKeySignature(KeySignature.dMajor);

    expect(notifier.score.notes[0].midi, 66);
    expect(notifier.score.notes[1].midi, 61);
    expect(notifier.score.notes[2].isRest, isTrue);
  });

  test('setKeySignature remaps notes from the previous key intent', () {
    final notifier = ScoreNotifier();

    notifier.score.notes.addAll([
      const Note(midi: 66, duration: NoteDuration.quarter),
      const Note(midi: 60, duration: NoteDuration.quarter),
    ]);
    notifier.setKeySignature(KeySignature.gMajor);

    notifier.setKeySignature(KeySignature.dMajor);

    expect(notifier.score.notes[0].midi, 66);
    expect(notifier.score.notes[1].midi, 61);
  });

  test('triplet input inserts three identical rests at once', () {
    final notifier = ScoreNotifier();

    notifier.toggleTripletMode();
    notifier.handleRestAction();
    notifier.setDuration(NoteDuration.eighth);

    expect(notifier.tripletMode, isFalse);
    expect(notifier.restMode, isFalse);
    expect(notifier.score.notes, hasLength(3));
    expect(notifier.score.notes.every((note) => note.isRest), isTrue);
    expect(
      notifier.score.notes.map((note) => note.tripletGroupId).toSet().length,
      1,
    );
  });

  test('triplet action clones the last selected note into a full triplet', () {
    final notifier = ScoreNotifier();

    notifier.score.addNote(
      const Note(midi: 67, duration: NoteDuration.quarter),
    );
    notifier.selectNote(0);

    expect(notifier.tripletButtonEnabled, isTrue);

    notifier.toggleTripletMode();

    expect(notifier.score.notes, hasLength(3));
    expect(notifier.selectedIndex, 0);
    expect(notifier.toolbarTripletSelected, isTrue);
    expect(notifier.score.notes.map((note) => note.midi), [67, 67, 67]);
    expect(
      notifier.score.notes.map((note) => note.tripletGroupId).toSet().length,
      1,
    );
  });

  test('triplet action converts and removes a valid three-note group', () {
    final notifier = ScoreNotifier();

    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
      const Note(midi: 64, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    expect(notifier.tripletButtonEnabled, isTrue);
    notifier.toggleTripletMode();

    final groupId = notifier.score.notes.first.tripletGroupId;
    expect(groupId, isNotNull);
    expect(
      notifier.score.notes.every((note) => note.tripletGroupId == groupId),
      isTrue,
    );

    notifier.toggleTripletMode();
    expect(
      notifier.score.notes.every((note) => note.tripletGroupId == null),
      isTrue,
    );
  });

  test('triplet action is disabled when next notes do not match timing', () {
    final notifier = ScoreNotifier();

    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.half),
      const Note(midi: 64, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    expect(notifier.tripletButtonEnabled, isFalse);
    notifier.toggleTripletMode();

    expect(
      notifier.score.notes.every((note) => note.tripletGroupId == null),
      isTrue,
    );
  });

  test(
    'triplet action is disabled when cloned triplet would overflow measure',
    () {
      final notifier = ScoreNotifier();

      notifier.setTimeSignature(3, 4);
      notifier.score.notes.addAll([
        const Note(midi: 60, duration: NoteDuration.quarter),
        const Note(midi: 62, duration: NoteDuration.quarter),
        const Note(midi: 64, duration: NoteDuration.quarter),
      ]);
      notifier.selectNote(2);

      expect(notifier.tripletButtonEnabled, isFalse);
      notifier.toggleTripletMode();

      expect(notifier.score.notes, hasLength(3));
      expect(
        notifier.score.notes.every((note) => note.tripletGroupId == null),
        isTrue,
      );
    },
  );

  test('slur input applies to the next pitched note and resets', () {
    final notifier = ScoreNotifier();

    notifier.toggleSlurMode();
    expect(notifier.slurMode, isTrue);

    notifier.insertPitchedNote(60);

    expect(notifier.slurMode, isFalse);
    expect(notifier.score.notes.single.slurToNext, isTrue);
  });

  test('selected pitched note toggles slur to next', () {
    final notifier = ScoreNotifier();
    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    expect(notifier.slurButtonEnabled, isTrue);
    notifier.toggleSlurMode();
    expect(notifier.score.notes.first.slurToNext, isTrue);

    notifier.toggleSlurMode();
    expect(notifier.score.notes.first.slurToNext, isFalse);
  });

  test('rest cannot be marked with a slur', () {
    final notifier = ScoreNotifier();
    notifier.score.notes.addAll([
      const Note.rest(duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    expect(notifier.slurButtonEnabled, isFalse);
    notifier.toggleSlurMode();

    expect(notifier.score.notes.first.slurToNext, isFalse);
  });

  test('delete removes the last note in end-input mode', () {
    final notifier = ScoreNotifier();
    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(null);

    expect(notifier.deleteButtonEnabled, isTrue);
    notifier.deleteSelected();

    expect(notifier.score.notes, hasLength(1));
    expect(notifier.score.notes.single.midi, 60);
    expect(notifier.selectionKind, isNull);
    expect(notifier.cursorIndex, 1);
  });

  test('deleting a slurred target clears the previous slur', () {
    final notifier = ScoreNotifier();
    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter, slurToNext: true),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(1);

    notifier.deleteSelected();

    expect(notifier.score.notes, hasLength(1));
    expect(notifier.score.notes.single.slurToNext, isFalse);
  });

  test('turning a slurred note into a rest clears adjacent slurs', () {
    final notifier = ScoreNotifier();
    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter, slurToNext: true),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(1);

    notifier.handleRestAction();

    expect(notifier.score.notes[0].slurToNext, isFalse);
    expect(notifier.score.notes[1].isRest, isTrue);
  });

  test(
    'play retriggers repeated same-pitch notes with separate highlights',
    () async {
      final audioService = _FakeAudioService();
      final notifier = ScoreNotifier(audioService: audioService);
      final playbackIndices = <int>[];

      notifier.addListener(() {
        if (notifier.playbackIndex >= 0) {
          playbackIndices.add(notifier.playbackIndex);
        }
      });
      notifier.score.notes.addAll([
        const Note(midi: 60, duration: NoteDuration.quarter),
        const Note(midi: 60, duration: NoteDuration.quarter),
      ]);

      await notifier.play();

      expect(audioService.events, [
        'start-60',
        'stop-60',
        'start-60',
        'stop-60',
      ]);
      expect(playbackIndices, containsAllInOrder([0, 1]));
      expect(notifier.playbackIndex, -1);
      expect(notifier.isPlaying, isFalse);
    },
  );
}

class _FakeAudioService extends AudioService {
  final List<String> events = [];
  int _nextHandleId = 1;

  @override
  Future<AudioNoteHandle?> startNote(
    int midi, {
    int velocity = AudioService.defaultPlaybackVelocity,
  }) async {
    events.add('start-$midi');
    return AudioNoteHandle(id: _nextHandleId++, midi: midi);
  }

  @override
  Future<void> stopNoteHandle(AudioNoteHandle handle) async {
    events.add('stop-${handle.midi}');
  }

  @override
  void stopPlayback() {}

  @override
  void dispose() {}
}
