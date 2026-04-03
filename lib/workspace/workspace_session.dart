import '../models/score.dart';
import '../models/score_library.dart';
import 'workspace_document.dart';

class WorkspaceSession {
  const WorkspaceSession({
    required this.editorScore,
    required this.document,
    required this.savedScores,
    required this.presetScores,
  });

  final Score editorScore;
  final WorkspaceDocument document;
  final List<SavedScoreEntry> savedScores;
  final List<PresetScoreEntry> presetScores;
}
