import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';
import 'package:tap_score/state/editable_score_session.dart';
import 'package:tap_score/workspace/workspace_document.dart';
import 'package:tap_score/workspace/workspace_session.dart';

void main() {
  test('starts as an empty draft with no unsaved changes', () {
    final session = EditableScoreSession();
    addTearDown(session.dispose);

    expect(session.score.notes, isEmpty);
    expect(session.currentScoreLabel, 'Draft');
    expect(session.referenceBpm, 120);
    expect(session.hasUnsavedChanges, isFalse);
    expect(session.savedScores, isEmpty);
    expect(session.presetScores, isEmpty);
  });

  test(
    'replaceWorkspace can replace the editor score and reset dirty state',
    () {
      final session = EditableScoreSession();
      addTearDown(session.dispose);
      final score = Score(
        notes: const [Note(midi: 65, duration: NoteDuration.half)],
        bpm: 88,
      );
      final saved = SavedScoreEntry(
        id: 'saved-1',
        name: 'Warmup',
        updatedAt: DateTime.utc(2026, 5, 10),
        score: score,
      );

      session.replaceWorkspace(
        WorkspaceSession(
          editorScore: score,
          document: WorkspaceDocument.saved(saved),
          savedScores: [saved],
          presetScores: const [],
        ),
        replaceScore: true,
      );

      expect(session.score.notes.single.midi, 65);
      expect(session.currentScoreLabel, 'Warmup');
      expect(session.activeScoreId, 'saved-1');
      expect(session.activeSavedScore?.name, 'Warmup');
      expect(session.referenceBpm, 88);
      expect(session.hasUnsavedChanges, isFalse);
    },
  );

  test('markScoreChanged updates dirty state and emits score changes', () {
    final session = EditableScoreSession();
    addTearDown(session.dispose);
    var scoreChanges = 0;
    var listenerCalls = 0;
    session.addScoreChangedListener(() => scoreChanges += 1);
    session.addListener(() => listenerCalls += 1);

    session.score.addNote(const Note(midi: 60));
    session.markScoreChanged();

    expect(session.hasUnsavedChanges, isTrue);
    expect(scoreChanges, 1);
    expect(listenerCalls, 1);
  });

  test(
    'replaceScore resets selection-independent score fields from source',
    () {
      final session = EditableScoreSession();
      addTearDown(session.dispose);
      final source = Score(
        notes: const [Note(midi: 48, duration: NoteDuration.whole)],
        beatsPerMeasure: 3,
        beatUnit: 8,
        bpm: 72,
        clef: Clef.bass,
      );

      session.replaceScore(source);

      expect(session.score.notes.single.midi, 48);
      expect(session.score.beatsPerMeasure, 3);
      expect(session.score.beatUnit, 8);
      expect(session.score.bpm, 72);
      expect(session.score.clef, Clef.bass);
    },
  );
}
