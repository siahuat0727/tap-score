import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/app/score_seed_config.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/portable_score_document.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';
import 'package:tap_score/services/preset_score_repository.dart';
import 'package:tap_score/services/score_library_repository.dart';
import 'package:tap_score/workspace/workspace_document.dart';
import 'package:tap_score/workspace/workspace_repository.dart';

void main() {
  test(
    'restore keeps saved document identity while loading draft score',
    () async {
      final repository = _MemoryScoreLibraryRepository(
        ScoreLibrarySnapshot(
          draft: Score(
            notes: const [Note(midi: 72, duration: NoteDuration.quarter)],
            bpm: 140,
          ),
          savedScores: [
            SavedScoreEntry(
              id: 'saved-1',
              name: 'Warmup',
              updatedAt: DateTime.utc(2026, 4, 1),
              score: Score(
                notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
                bpm: 90,
              ),
            ),
          ],
          activeScoreId: 'saved-1',
        ),
      );
      final workspaceRepository = DefaultWorkspaceRepository(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );

      final result = await workspaceRepository.loadWorkspace();
      final workspace = result.workspace;

      expect(workspace.document.source, WorkspaceDocumentSource.saved);
      expect(workspace.document.savedScoreId, 'saved-1');
      expect(workspace.document.score.bpm, 90);
      expect(workspace.editorScore.bpm, 140);
    },
  );

  test(
    'saved seed loads the requested score and persists it as the active document',
    () async {
      final repository = _MemoryScoreLibraryRepository(
        ScoreLibrarySnapshot(
          draft: Score(),
          savedScores: [
            SavedScoreEntry(
              id: 'saved-1',
              name: 'Solo',
              updatedAt: DateTime.utc(2026, 4, 1),
              score: Score(
                notes: const [Note(midi: 67, duration: NoteDuration.half)],
                bpm: 88,
              ),
            ),
          ],
        ),
      );
      final workspaceRepository = DefaultWorkspaceRepository(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );

      final result = await workspaceRepository.loadWorkspace(
        initialScoreConfig: const ScoreSeedConfig.saved('saved-1'),
      );
      final workspace = result.workspace;

      expect(workspace.document.savedScoreId, 'saved-1');
      expect(workspace.editorScore.bpm, 88);
      expect(repository.snapshot?.activeScoreId, isNull);
      expect(repository.snapshot?.draft.bpm, 120);
    },
  );

  test(
    'persistDraft keeps preset identity while storing edited draft',
    () async {
      final repository = _MemoryScoreLibraryRepository();
      final workspaceRepository = DefaultWorkspaceRepository(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(
          presets: [
            PresetScoreEntry(
              id: 'preset-1',
              name: 'Triplet Study',
              assetPath: 'assets/presets/triplet_study.json',
              score: Score(
                notes: const [Note(midi: 67, duration: NoteDuration.quarter)],
                bpm: 96,
              ),
            ),
          ],
        ),
      );

      final result = await workspaceRepository.loadWorkspace(
        initialScoreConfig: const ScoreSeedConfig.preset('preset-1'),
      );
      final workspace = result.workspace;
      final editedScore = workspace.editorScore.copy()..bpm = 132;

      await workspaceRepository.persistDraft(
        workspace: workspace,
        editedScore: editedScore,
      );

      expect(repository.snapshot?.activePresetId, 'preset-1');
      expect(repository.snapshot?.activeScoreId, isNull);
      expect(repository.snapshot?.draft.bpm, 132);
    },
  );

  test('import stores the imported label in the draft snapshot', () async {
    final repository = _MemoryScoreLibraryRepository();
    final workspaceRepository = DefaultWorkspaceRepository(
      scoreLibraryRepository: repository,
      presetScoreRepository: _MemoryPresetScoreRepository(),
    );
    final initialResult = await workspaceRepository.loadWorkspace();
    final initialWorkspace = initialResult.workspace;

    await workspaceRepository.importDocument(
      workspace: initialWorkspace,
      document: PortableScoreDocument(
        version: PortableScoreDocument.currentVersion,
        name: 'Imported Groove',
        score: Score(
          notes: const [Note(midi: 72, duration: NoteDuration.whole)],
          bpm: 72,
        ),
      ),
    );

    expect(repository.snapshot?.draftLabel, 'Imported Groove');
    expect(repository.snapshot?.draft.bpm, 72);
  });

  test('blank launch still resolves when preset loading fails', () async {
    final workspaceRepository = DefaultWorkspaceRepository(
      scoreLibraryRepository: _MemoryScoreLibraryRepository(
        ScoreLibrarySnapshot(
          draft: Score(
            notes: const [Note(midi: 64, duration: NoteDuration.quarter)],
            bpm: 90,
          ),
          savedScores: [
            SavedScoreEntry(
              id: 'saved-1',
              name: 'Saved Piece',
              updatedAt: DateTime.utc(2026, 4, 1),
              score: Score(
                notes: const [Note(midi: 60, duration: NoteDuration.half)],
              ),
            ),
          ],
        ),
      ),
      presetScoreRepository: _ThrowingPresetScoreRepository(),
    );

    final result = await workspaceRepository.loadWorkspace(
      initialScoreConfig: const ScoreSeedConfig.blank(),
    );

    expect(result.workspace.document.source, WorkspaceDocumentSource.draft);
    expect(result.workspace.editorScore.notes, isEmpty);
    expect(result.workspace.savedScores, hasLength(1));
    expect(result.workspace.presetScores, isEmpty);
    expect(result.warningMessage, 'Failed to load preset score manifest.');
  });

  test('preset launch still fails when preset loading fails', () async {
    final workspaceRepository = DefaultWorkspaceRepository(
      scoreLibraryRepository: _MemoryScoreLibraryRepository(),
      presetScoreRepository: _ThrowingPresetScoreRepository(),
    );

    expect(
      () => workspaceRepository.loadWorkspace(
        initialScoreConfig: const ScoreSeedConfig.preset('preset-1'),
      ),
      throwsA(isA<PresetScoreException>()),
    );
  });
}

class _MemoryScoreLibraryRepository implements ScoreLibraryRepository {
  _MemoryScoreLibraryRepository([this.snapshot]);

  ScoreLibrarySnapshot? snapshot;

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot nextSnapshot) async {
    snapshot = nextSnapshot;
  }
}

class _MemoryPresetScoreRepository implements PresetScoreRepository {
  _MemoryPresetScoreRepository({this.presets = const []});

  final List<PresetScoreEntry> presets;

  @override
  Future<List<PresetScoreEntry>> loadPresets() async => presets;
}

class _ThrowingPresetScoreRepository implements PresetScoreRepository {
  @override
  Future<List<PresetScoreEntry>> loadPresets() async {
    throw const PresetScoreException('Failed to load preset score manifest.');
  }
}
