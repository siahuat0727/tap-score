import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/app/score_seed_config.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/portable_score_document.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';
import 'package:tap_score/state/score_notifier.dart';
import 'package:tap_score/workspace/workspace_document.dart';
import 'package:tap_score/workspace/workspace_repository.dart';
import 'package:tap_score/workspace/workspace_session.dart';

void main() {
  test(
    'library loads reset editor state before notifier listeners run',
    () async {
      final repository = _ShortScoreLoadRepository();
      final notifier = ScoreNotifier(workspaceRepository: repository);
      addTearDown(notifier.dispose);

      await notifier.loadInitialWorkspace();
      notifier.selectNote(1);

      var observedInvalidSelection = false;
      notifier.addListener(() {
        final selectedIndex = notifier.selectedIndex;
        if (selectedIndex != null &&
            selectedIndex >= notifier.score.notes.length) {
          observedInvalidSelection = true;
        }
        notifier.selectedNote;
      });

      await notifier.loadSavedScore('short');

      expect(observedInvalidSelection, isFalse);
      expect(notifier.selectedIndex, isNull);
      expect(notifier.score.notes, hasLength(1));
    },
  );
}

class _ShortScoreLoadRepository extends WorkspaceRepository {
  final SavedScoreEntry _shortScore = SavedScoreEntry(
    id: 'short',
    name: 'Short',
    updatedAt: DateTime.utc(2026, 5, 20),
    score: Score(notes: const [Note(midi: 60)]),
  );

  @override
  Future<WorkspaceLoadResult> loadWorkspace({
    ScoreSeedConfig? initialScoreConfig,
  }) async {
    final initialScore = Score(notes: const [Note(midi: 60), Note(midi: 62)]);
    return WorkspaceLoadResult(
      workspace: WorkspaceSession(
        editorScore: initialScore,
        document: WorkspaceDocument.draft(score: initialScore),
        savedScores: [_shortScore],
        presetScores: const [],
      ),
    );
  }

  @override
  Future<WorkspaceSession> loadSavedScore({
    required WorkspaceSession workspace,
    required String id,
  }) async {
    return WorkspaceSession(
      editorScore: _shortScore.score.copy(),
      document: WorkspaceDocument.saved(_shortScore),
      savedScores: workspace.savedScores,
      presetScores: workspace.presetScores,
    );
  }

  @override
  Future<WorkspaceLoadResult> restoreDraft() {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceSession> saveCurrentScore({
    required WorkspaceSession workspace,
    required Score editedScore,
    required String name,
    bool createNew = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceSession> loadPresetScore({
    required WorkspaceSession workspace,
    required String id,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceSession> importDocument({
    required WorkspaceSession workspace,
    required PortableScoreDocument document,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceSession> deleteSavedScore({
    required WorkspaceSession workspace,
    required String id,
    required Score currentScore,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> persistDraft({
    required WorkspaceSession workspace,
    required Score editedScore,
  }) async {}
}
