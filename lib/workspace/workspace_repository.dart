import '../app/score_seed_config.dart';
import '../models/portable_score_document.dart';
import '../models/score.dart';
import '../models/score_library.dart';
import '../services/preset_score_repository.dart';
import '../services/score_library_repository.dart';
import 'workspace_document.dart';
import 'workspace_session.dart';

class WorkspaceRepositoryException implements Exception {
  const WorkspaceRepositoryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'WorkspaceRepositoryException: $message'
        : 'WorkspaceRepositoryException: $message ($cause)';
  }
}

class WorkspaceLoadResult {
  const WorkspaceLoadResult({required this.workspace, this.warningMessage});

  final WorkspaceSession workspace;
  final String? warningMessage;
}

abstract class WorkspaceRepository {
  Future<WorkspaceLoadResult> loadWorkspace({
    ScoreSeedConfig? initialScoreConfig,
  });

  Future<WorkspaceLoadResult> restoreDraft();

  Future<WorkspaceSession> saveCurrentScore({
    required WorkspaceSession workspace,
    required Score editedScore,
    required String name,
    bool createNew = false,
  });

  Future<WorkspaceSession> loadSavedScore({
    required WorkspaceSession workspace,
    required String id,
  });

  Future<WorkspaceSession> loadPresetScore({
    required WorkspaceSession workspace,
    required String id,
  });

  Future<WorkspaceSession> importDocument({
    required WorkspaceSession workspace,
    required PortableScoreDocument document,
  });

  Future<WorkspaceSession> deleteSavedScore({
    required WorkspaceSession workspace,
    required String id,
    required Score currentScore,
  });

  Future<void> persistDraft({
    required WorkspaceSession workspace,
    required Score editedScore,
  });
}

class DefaultWorkspaceRepository implements WorkspaceRepository {
  DefaultWorkspaceRepository({
    ScoreLibraryRepository? scoreLibraryRepository,
    PresetScoreRepository? presetScoreRepository,
  }) : _scoreLibraryRepository =
           scoreLibraryRepository ?? SharedPreferencesScoreLibraryRepository(),
       _presetScoreRepository =
           presetScoreRepository ?? AssetPresetScoreRepository();

  final ScoreLibraryRepository _scoreLibraryRepository;
  final PresetScoreRepository _presetScoreRepository;

  @override
  Future<WorkspaceLoadResult> loadWorkspace({
    ScoreSeedConfig? initialScoreConfig,
  }) async {
    final snapshot = await _scoreLibraryRepository.loadSnapshot();
    final presetCatalog = await _loadPresetCatalog(
      allowFailure: initialScoreConfig?.isPreset != true,
    );
    final savedScores = _sortSavedScores(snapshot?.savedScores ?? const []);
    final workspace = _resolveWorkspace(
      presetScores: presetCatalog.presetScores,
      savedScores: savedScores,
      snapshot: snapshot,
      initialScoreConfig: initialScoreConfig,
    );
    return WorkspaceLoadResult(
      workspace: workspace,
      warningMessage: presetCatalog.warningMessage,
    );
  }

  @override
  Future<WorkspaceLoadResult> restoreDraft() async {
    final snapshot = await _scoreLibraryRepository.loadSnapshot();
    if (snapshot == null) {
      throw const WorkspaceRepositoryException(
        'No draft is stored on this device.',
      );
    }

    final presetCatalog = await _loadPresetCatalog(allowFailure: true);
    return WorkspaceLoadResult(
      workspace: _sessionFromSnapshot(
        snapshot: snapshot,
        presetScores: presetCatalog.presetScores,
        savedScores: _sortSavedScores(snapshot.savedScores),
      ),
      warningMessage: presetCatalog.warningMessage,
    );
  }

  @override
  Future<WorkspaceSession> saveCurrentScore({
    required WorkspaceSession workspace,
    required Score editedScore,
    required String name,
    bool createNew = false,
  }) async {
    final now = DateTime.now();
    final id = createNew || workspace.document.savedScoreId == null
        ? 'score-${now.microsecondsSinceEpoch}'
        : workspace.document.savedScoreId!;
    final updatedEntry = SavedScoreEntry(
      id: id,
      name: name,
      updatedAt: now,
      score: editedScore.copy(),
    );

    final savedScores = _sortSavedScores([
      for (final entry in workspace.savedScores)
        if (entry.id != id) entry,
      updatedEntry,
    ]);

    final nextWorkspace = WorkspaceSession(
      editorScore: editedScore.copy(),
      document: WorkspaceDocument.saved(updatedEntry),
      savedScores: savedScores,
      presetScores: workspace.presetScores,
    );
    await _persistWorkspace(workspace: nextWorkspace, editedScore: editedScore);
    return nextWorkspace;
  }

  @override
  Future<WorkspaceSession> loadSavedScore({
    required WorkspaceSession workspace,
    required String id,
  }) async {
    final entry = workspace.savedScores.firstWhere(
      (candidate) => candidate.id == id,
      orElse: () => throw WorkspaceRepositoryException(
        'Saved score "$id" does not exist.',
      ),
    );

    final nextWorkspace = WorkspaceSession(
      editorScore: entry.score.copy(),
      document: WorkspaceDocument.saved(entry),
      savedScores: workspace.savedScores,
      presetScores: workspace.presetScores,
    );
    await _persistWorkspace(
      workspace: nextWorkspace,
      editedScore: nextWorkspace.editorScore,
    );
    return nextWorkspace;
  }

  @override
  Future<WorkspaceSession> loadPresetScore({
    required WorkspaceSession workspace,
    required String id,
  }) async {
    final entry = workspace.presetScores.firstWhere(
      (candidate) => candidate.id == id,
      orElse: () =>
          throw WorkspaceRepositoryException('Preset "$id" does not exist.'),
    );

    final nextWorkspace = WorkspaceSession(
      editorScore: entry.score.copy(),
      document: WorkspaceDocument.preset(entry),
      savedScores: workspace.savedScores,
      presetScores: workspace.presetScores,
    );
    await _persistWorkspace(
      workspace: nextWorkspace,
      editedScore: nextWorkspace.editorScore,
    );
    return nextWorkspace;
  }

  @override
  Future<WorkspaceSession> importDocument({
    required WorkspaceSession workspace,
    required PortableScoreDocument document,
  }) async {
    final nextWorkspace = WorkspaceSession(
      editorScore: document.score.copy(),
      document: WorkspaceDocument.imported(
        name: document.name,
        score: document.score,
      ),
      savedScores: workspace.savedScores,
      presetScores: workspace.presetScores,
    );
    await _persistWorkspace(
      workspace: nextWorkspace,
      editedScore: nextWorkspace.editorScore,
    );
    return nextWorkspace;
  }

  @override
  Future<WorkspaceSession> deleteSavedScore({
    required WorkspaceSession workspace,
    required String id,
    required Score currentScore,
  }) async {
    SavedScoreEntry? removedEntry;
    final savedScores = <SavedScoreEntry>[];
    for (final entry in workspace.savedScores) {
      if (entry.id == id) {
        removedEntry = entry;
      } else {
        savedScores.add(entry);
      }
    }
    if (removedEntry == null) {
      throw WorkspaceRepositoryException('Saved score "$id" does not exist.');
    }

    final currentDocument = workspace.document.savedScoreId == id
        ? WorkspaceDocument.draft(score: currentScore)
        : workspace.document;
    final nextWorkspace = WorkspaceSession(
      editorScore: currentScore.copy(),
      document: currentDocument,
      savedScores: _sortSavedScores(savedScores),
      presetScores: workspace.presetScores,
    );
    await _persistWorkspace(
      workspace: nextWorkspace,
      editedScore: nextWorkspace.editorScore,
    );
    return nextWorkspace;
  }

  @override
  Future<void> persistDraft({
    required WorkspaceSession workspace,
    required Score editedScore,
  }) {
    return _persistWorkspace(workspace: workspace, editedScore: editedScore);
  }

  Future<_PresetCatalogLoadResult> _loadPresetCatalog({
    required bool allowFailure,
  }) async {
    try {
      return _PresetCatalogLoadResult(
        presetScores: await _presetScoreRepository.loadPresets(),
      );
    } on PresetScoreException catch (error) {
      if (!allowFailure) {
        rethrow;
      }
      return _PresetCatalogLoadResult(
        presetScores: const [],
        warningMessage: error.message,
      );
    }
  }

  WorkspaceSession _resolveWorkspace({
    required List<PresetScoreEntry> presetScores,
    required List<SavedScoreEntry> savedScores,
    required ScoreLibrarySnapshot? snapshot,
    required ScoreSeedConfig? initialScoreConfig,
  }) {
    final seedConfig = initialScoreConfig ?? const ScoreSeedConfig.restore();
    switch (seedConfig.kind) {
      case ScoreSeedKind.imported:
        final document = seedConfig.document!;
        return WorkspaceSession(
          editorScore: document.score.copy(),
          document: WorkspaceDocument.imported(
            name: document.name,
            score: document.score,
          ),
          savedScores: savedScores,
          presetScores: List.unmodifiable(presetScores),
        );
      case ScoreSeedKind.preset:
        final presetId = seedConfig.presetId!;
        final entry = presetScores.cast<PresetScoreEntry?>().firstWhere(
          (candidate) => candidate?.id == presetId,
          orElse: () => null,
        );
        if (entry == null) {
          throw WorkspaceRepositoryException(
            'Preset "$presetId" does not exist.',
          );
        }
        return WorkspaceSession(
          editorScore: entry.score.copy(),
          document: WorkspaceDocument.preset(entry),
          savedScores: savedScores,
          presetScores: List.unmodifiable(presetScores),
        );
      case ScoreSeedKind.saved:
        final savedScoreId = seedConfig.savedScoreId!;
        final entry = savedScores.cast<SavedScoreEntry?>().firstWhere(
          (candidate) => candidate?.id == savedScoreId,
          orElse: () => null,
        );
        if (entry == null) {
          throw WorkspaceRepositoryException(
            'Saved score "$savedScoreId" does not exist.',
          );
        }
        return WorkspaceSession(
          editorScore: entry.score.copy(),
          document: WorkspaceDocument.saved(entry),
          savedScores: savedScores,
          presetScores: List.unmodifiable(presetScores),
        );
      case ScoreSeedKind.blank:
        return WorkspaceSession(
          editorScore: Score(),
          document: WorkspaceDocument.draft(score: Score()),
          savedScores: savedScores,
          presetScores: List.unmodifiable(presetScores),
        );
      case ScoreSeedKind.restore:
        if (snapshot == null) {
          return WorkspaceSession(
            editorScore: Score(),
            document: WorkspaceDocument.draft(score: Score()),
            savedScores: savedScores,
            presetScores: List.unmodifiable(presetScores),
          );
        }
        return _sessionFromSnapshot(
          snapshot: snapshot,
          presetScores: presetScores,
          savedScores: savedScores,
        );
    }
  }

  WorkspaceSession _sessionFromSnapshot({
    required ScoreLibrarySnapshot snapshot,
    required List<PresetScoreEntry> presetScores,
    required List<SavedScoreEntry> savedScores,
  }) {
    final editorScore = snapshot.draft.copy();
    final document = _documentFromSnapshot(
      snapshot: snapshot,
      editorScore: editorScore,
      presetScores: presetScores,
      savedScores: savedScores,
    );
    return WorkspaceSession(
      editorScore: editorScore,
      document: document,
      savedScores: savedScores,
      presetScores: List.unmodifiable(presetScores),
    );
  }

  WorkspaceDocument _documentFromSnapshot({
    required ScoreLibrarySnapshot snapshot,
    required Score editorScore,
    required List<PresetScoreEntry> presetScores,
    required List<SavedScoreEntry> savedScores,
  }) {
    if (snapshot.activeScoreId case final activeScoreId?) {
      for (final entry in savedScores) {
        if (entry.id == activeScoreId) {
          return WorkspaceDocument.saved(entry);
        }
      }
    }

    if (snapshot.activePresetId case final activePresetId?) {
      for (final entry in presetScores) {
        if (entry.id == activePresetId) {
          return WorkspaceDocument.preset(entry);
        }
      }
    }

    if (snapshot.draftLabel case final draftLabel?) {
      return WorkspaceDocument.imported(name: draftLabel, score: editorScore);
    }

    return WorkspaceDocument.draft(score: editorScore);
  }

  Future<void> _persistWorkspace({
    required WorkspaceSession workspace,
    required Score editedScore,
  }) {
    return _scoreLibraryRepository.saveSnapshot(
      ScoreLibrarySnapshot(
        draft: editedScore.copy(),
        savedScores: [
          for (final entry in workspace.savedScores)
            entry.copyWith(score: entry.score.copy()),
        ],
        activeScoreId: workspace.document.savedScoreId,
        activePresetId: workspace.document.presetId,
        draftLabel: workspace.document.isImported
            ? workspace.document.name
            : null,
      ),
    );
  }

  List<SavedScoreEntry> _sortSavedScores(List<SavedScoreEntry> entries) {
    final sorted = List<SavedScoreEntry>.from(entries);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(sorted);
  }
}

class _PresetCatalogLoadResult {
  const _PresetCatalogLoadResult({
    required this.presetScores,
    this.warningMessage,
  });

  final List<PresetScoreEntry> presetScores;
  final String? warningMessage;
}
