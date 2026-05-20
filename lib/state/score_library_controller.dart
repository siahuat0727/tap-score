import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/score_seed_config.dart';
import '../models/portable_score_document.dart';
import '../models/score_library.dart';
import '../services/preset_score_repository.dart';
import '../services/score_library_repository.dart';
import '../workspace/workspace_repository.dart';
import '../workspace/workspace_session.dart';
import 'editable_score_session.dart';
import 'playback_controller.dart';

class ScoreLibraryController extends ChangeNotifier {
  static const Duration _draftSaveDelay = Duration(milliseconds: 250);

  ScoreLibraryController({
    required EditableScoreSession session,
    required PlaybackController playback,
    required WorkspaceRepository workspaceRepository,
  }) : _session = session,
       _playback = playback,
       _workspaceRepository = workspaceRepository {
    _session.addScoreChangedListener(_scheduleDraftSave);
  }

  final EditableScoreSession _session;
  final PlaybackController _playback;
  final WorkspaceRepository _workspaceRepository;

  Timer? _draftSaveTimer;
  Timer? _libraryMessageTimer;
  int _initialWorkspaceLoadGeneration = 0;
  Future<void> _initialWorkspacePersistence = Future<void>.value();
  bool _initialWorkspaceLoadComplete = false;
  bool _initialWorkspaceLoadSucceeded = false;
  String? _libraryMessage;
  bool _libraryMessageIsError = false;

  List<SavedScoreEntry> get savedScores => _session.savedScores;
  List<PresetScoreEntry> get presetScores => _session.presetScores;
  String? get activeScoreId => _session.activeScoreId;
  String? get activePresetId => _session.activePresetId;
  SavedScoreEntry? get activeSavedScore => _session.activeSavedScore;
  PresetScoreEntry? get activePresetScore => _session.activePresetScore;
  String get currentScoreLabel => _session.currentScoreLabel;
  bool get hasUnsavedChanges => _session.hasUnsavedChanges;
  bool get initialWorkspaceLoadComplete => _initialWorkspaceLoadComplete;
  bool get initialWorkspaceLoadSucceeded => _initialWorkspaceLoadSucceeded;
  String? get libraryMessage => _libraryMessage;
  bool get libraryMessageIsError => _libraryMessageIsError;

  Future<void> loadInitialWorkspace({
    ScoreSeedConfig? initialScoreConfig,
  }) async {
    final loadGeneration = ++_initialWorkspaceLoadGeneration;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    _initialWorkspaceLoadComplete = false;
    _initialWorkspaceLoadSucceeded = false;
    _libraryMessageTimer?.cancel();
    _libraryMessage = null;
    _libraryMessageIsError = false;
    notifyListeners();

    try {
      final result = await _workspaceRepository.loadWorkspace(
        initialScoreConfig: initialScoreConfig,
      );
      if (loadGeneration != _initialWorkspaceLoadGeneration) {
        return;
      }
      _applyWorkspaceLoadResult(result, replaceScore: true);
      _initialWorkspaceLoadSucceeded = true;
      if (initialScoreConfig != null && !initialScoreConfig.isRestore) {
        await _persistInitializedWorkspace(
          result.workspace,
          loadGeneration: loadGeneration,
        );
      } else {
        await _initialWorkspacePersistence;
      }
      if (loadGeneration != _initialWorkspaceLoadGeneration) {
        return;
      }
    } on WorkspaceRepositoryException catch (error) {
      if (loadGeneration != _initialWorkspaceLoadGeneration) {
        return;
      }
      _initialWorkspaceLoadSucceeded = false;
      _setLibraryMessage(error.message, isError: true);
    } on PresetScoreException catch (error) {
      if (loadGeneration != _initialWorkspaceLoadGeneration) {
        return;
      }
      _initialWorkspaceLoadSucceeded = false;
      _setLibraryMessage(error.message, isError: true);
    } on ScoreLibraryStorageException catch (error) {
      if (loadGeneration != _initialWorkspaceLoadGeneration) {
        return;
      }
      _initialWorkspaceLoadSucceeded = false;
      _setLibraryMessage(error.message, isError: true);
    } catch (error) {
      if (loadGeneration != _initialWorkspaceLoadGeneration) {
        return;
      }
      _initialWorkspaceLoadSucceeded = false;
      _setLibraryMessage('Failed to load the workspace.', isError: true);
      debugPrint('Workspace load failed: $error');
    }

    _initialWorkspaceLoadComplete = true;
    notifyListeners();
  }

  void clearLibraryMessage() {
    if (_libraryMessage == null) {
      return;
    }
    _libraryMessage = null;
    _libraryMessageIsError = false;
    notifyListeners();
  }

  void showLibraryMessage(String message, {required bool isError}) {
    _setLibraryMessage(message, isError: isError);
    notifyListeners();
  }

  Future<void> restoreDraft() async {
    try {
      _playback.stop();
      final result = await _workspaceRepository.restoreDraft();
      final hasWarning = _applyWorkspaceLoadResult(result, replaceScore: true);
      if (!hasWarning) {
        _setLibraryMessage('Draft restored.', isError: false);
      }
    } on WorkspaceRepositoryException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    } on ScoreLibraryStorageException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    }
    notifyListeners();
  }

  Future<void> saveCurrentScore(String name, {bool createNew = false}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _setLibraryMessage('Score name cannot be empty.', isError: true);
      notifyListeners();
      return;
    }

    try {
      final workspace = await _workspaceRepository.saveCurrentScore(
        workspace: _session.workspace,
        editedScore: _session.score,
        name: trimmedName,
        createNew: createNew,
      );
      _session.replaceWorkspace(workspace, replaceScore: false);
      _setLibraryMessage('Saved "$trimmedName".', isError: false);
    } on WorkspaceRepositoryException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    } on ScoreLibraryStorageException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    }

    notifyListeners();
  }

  Future<void> loadSavedScore(String id) async {
    try {
      _playback.stop();
      final workspace = await _workspaceRepository.loadSavedScore(
        workspace: _session.workspace,
        id: id,
      );
      _session.replaceWorkspace(workspace, replaceScore: true);
      _setLibraryMessage(
        'Loaded "${workspace.document.name}".',
        isError: false,
      );
    } on WorkspaceRepositoryException catch (error) {
      throw ArgumentError.value(id, 'id', error.message);
    } on ScoreLibraryStorageException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    }

    notifyListeners();
  }

  Future<void> loadPresetScore(String id) async {
    try {
      _playback.stop();
      final workspace = await _workspaceRepository.loadPresetScore(
        workspace: _session.workspace,
        id: id,
      );
      _session.replaceWorkspace(workspace, replaceScore: true);
      _setLibraryMessage(
        'Loaded "${workspace.document.name}".',
        isError: false,
      );
    } on WorkspaceRepositoryException catch (error) {
      throw ArgumentError.value(id, 'id', error.message);
    } on ScoreLibraryStorageException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    }

    notifyListeners();
  }

  Future<void> importScoreDocument(PortableScoreDocument document) async {
    try {
      _playback.stop();
      final workspace = await _workspaceRepository.importDocument(
        workspace: _session.workspace,
        document: document,
      );
      _session.replaceWorkspace(workspace, replaceScore: true);
      _setLibraryMessage('Imported "${document.name}".', isError: false);
    } on ScoreLibraryStorageException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    }

    notifyListeners();
  }

  PortableScoreDocument buildPortableDocument() {
    return PortableScoreDocument(
      version: PortableScoreDocument.currentVersion,
      name: currentScoreLabel,
      score: _session.score.copy(),
    );
  }

  Future<void> deleteSavedScore(String id) async {
    try {
      final removedEntry = savedScores.firstWhere(
        (entry) => entry.id == id,
        orElse: () =>
            throw ArgumentError.value(id, 'id', 'Saved score does not exist'),
      );
      final workspace = await _workspaceRepository.deleteSavedScore(
        workspace: _session.workspace,
        id: id,
        currentScore: _session.score,
      );
      _session.replaceWorkspace(workspace, replaceScore: false);
      _setLibraryMessage('Deleted "${removedEntry.name}".', isError: false);
    } on ScoreLibraryStorageException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    }

    notifyListeners();
  }

  bool _applyWorkspaceLoadResult(
    WorkspaceLoadResult result, {
    required bool replaceScore,
  }) {
    _session.replaceWorkspace(result.workspace, replaceScore: replaceScore);
    final warningMessage = result.warningMessage;
    if (warningMessage == null) {
      return false;
    }
    _setLibraryMessage(warningMessage, isError: true);
    return true;
  }

  Future<void> _persistInitializedWorkspace(
    WorkspaceSession workspace, {
    required int loadGeneration,
  }) async {
    final previousPersistence = _initialWorkspacePersistence;
    final currentPersistence = Completer<void>();
    _initialWorkspacePersistence = currentPersistence.future;
    try {
      await previousPersistence;
      if (loadGeneration != _initialWorkspaceLoadGeneration) {
        return;
      }
      await _workspaceRepository.persistDraft(
        workspace: workspace,
        editedScore: workspace.editorScore,
      );
    } on ScoreLibraryStorageException catch (error) {
      if (loadGeneration != _initialWorkspaceLoadGeneration) {
        return;
      }
      _setLibraryMessage(error.message, isError: true);
    } finally {
      currentPersistence.complete();
    }
  }

  void _scheduleDraftSave() {
    if (!_initialWorkspaceLoadComplete || !_initialWorkspaceLoadSucceeded) {
      return;
    }
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDelay, () async {
      try {
        await _workspaceRepository.persistDraft(
          workspace: _session.workspace,
          editedScore: _session.score,
        );
      } on ScoreLibraryStorageException {
        notifyListeners();
      }
    });
  }

  void _setLibraryMessage(String message, {required bool isError}) {
    _libraryMessageTimer?.cancel();
    _libraryMessage = message;
    _libraryMessageIsError = isError;
    if (!isError) {
      _libraryMessageTimer = Timer(const Duration(seconds: 3), () {
        clearLibraryMessage();
      });
    }
  }

  @override
  void dispose() {
    _session.removeScoreChangedListener(_scheduleDraftSave);
    _libraryMessageTimer?.cancel();
    _draftSaveTimer?.cancel();
    super.dispose();
  }
}
