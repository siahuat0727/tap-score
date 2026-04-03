import '../models/score.dart';
import '../models/score_library.dart';

enum WorkspaceDocumentSource { draft, saved, preset, imported }

class WorkspaceDocument {
  const WorkspaceDocument._({
    required this.source,
    required this.score,
    required this.name,
    this.savedScoreId,
    this.presetId,
  });

  factory WorkspaceDocument.draft({required Score score, String name = 'Draft'}) {
    return WorkspaceDocument._(
      source: WorkspaceDocumentSource.draft,
      score: score.copy(),
      name: name,
    );
  }

  factory WorkspaceDocument.saved(SavedScoreEntry entry) {
    return WorkspaceDocument._(
      source: WorkspaceDocumentSource.saved,
      score: entry.score.copy(),
      name: entry.name,
      savedScoreId: entry.id,
    );
  }

  factory WorkspaceDocument.preset(PresetScoreEntry entry) {
    return WorkspaceDocument._(
      source: WorkspaceDocumentSource.preset,
      score: entry.score.copy(),
      name: entry.name,
      presetId: entry.id,
    );
  }

  factory WorkspaceDocument.imported({
    required String name,
    required Score score,
  }) {
    return WorkspaceDocument._(
      source: WorkspaceDocumentSource.imported,
      score: score.copy(),
      name: name,
    );
  }

  final WorkspaceDocumentSource source;
  final Score score;
  final String name;
  final String? savedScoreId;
  final String? presetId;

  bool get isSaved => source == WorkspaceDocumentSource.saved;
  bool get isPreset => source == WorkspaceDocumentSource.preset;
  bool get isImported => source == WorkspaceDocumentSource.imported;
}
