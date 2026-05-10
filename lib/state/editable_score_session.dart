import 'package:flutter/foundation.dart';

import '../models/score.dart';
import '../models/score_library.dart';
import '../workspace/workspace_document.dart';
import '../workspace/workspace_session.dart';

class EditableScoreSession extends ChangeNotifier {
  EditableScoreSession() {
    _workspace = WorkspaceSession(
      editorScore: score.copy(),
      document: WorkspaceDocument.draft(score: score),
      savedScores: const [],
      presetScores: const [],
    );
  }

  final Score score = Score();
  late WorkspaceSession _workspace;
  bool _hasUnsavedChanges = false;
  final List<VoidCallback> _scoreChangedListeners = [];

  WorkspaceSession get workspace => _workspace;

  List<SavedScoreEntry> get savedScores =>
      List.unmodifiable(_workspace.savedScores);

  List<PresetScoreEntry> get presetScores =>
      List.unmodifiable(_workspace.presetScores);

  String? get activeScoreId => _workspace.document.savedScoreId;

  String? get activePresetId => _workspace.document.presetId;

  SavedScoreEntry? get activeSavedScore {
    final id = activeScoreId;
    if (id == null) return null;
    for (final entry in savedScores) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  PresetScoreEntry? get activePresetScore {
    final id = activePresetId;
    if (id == null) return null;
    for (final entry in presetScores) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  String get currentScoreLabel => _workspace.document.name;

  double get referenceBpm => _workspace.document.score.bpm;

  bool get hasUnsavedChanges => _hasUnsavedChanges;

  void addScoreChangedListener(VoidCallback listener) {
    _scoreChangedListeners.add(listener);
  }

  void removeScoreChangedListener(VoidCallback listener) {
    _scoreChangedListeners.remove(listener);
  }

  void replaceWorkspace(
    WorkspaceSession workspace, {
    required bool replaceScore,
  }) {
    _workspace = workspace;
    if (replaceScore) {
      replaceScoreFromWorkspace(workspace.editorScore);
    }
    _hasUnsavedChanges = _computeHasUnsavedChanges(score);
    notifyListeners();
  }

  void replaceScoreFromWorkspace(Score source) {
    replaceScore(source, notify: false);
  }

  void replaceScore(Score source, {bool notify = true}) {
    score.notes
      ..clear()
      ..addAll(source.notes);
    score.beatsPerMeasure = source.beatsPerMeasure;
    score.beatUnit = source.beatUnit;
    score.bpm = source.bpm;
    score.clef = source.clef;
    score.keySignature = source.keySignature;
    _hasUnsavedChanges = _computeHasUnsavedChanges(score);
    if (notify) {
      notifyListeners();
    }
  }

  void markScoreChanged() {
    _hasUnsavedChanges = _computeHasUnsavedChanges(score);
    for (final listener in List<VoidCallback>.from(_scoreChangedListeners)) {
      listener();
    }
    notifyListeners();
  }

  bool _computeHasUnsavedChanges(Score candidate) {
    return candidate != _workspace.document.score;
  }

  @override
  void dispose() {
    _scoreChangedListeners.clear();
    super.dispose();
  }
}
