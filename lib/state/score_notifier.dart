import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/score_seed_config.dart';
import '../input/editor_shortcuts.dart';
import '../models/enums.dart';
import '../models/key_signature.dart';
import '../models/note.dart';
import '../models/portable_score_document.dart';
import '../models/score.dart';
import '../models/score_library.dart';
import '../services/audio_service.dart';
import '../services/preset_score_repository.dart';
import '../services/score_library_repository.dart';
import '../workspace/workspace_document.dart';
import '../workspace/workspace_repository.dart';
import '../workspace/workspace_session.dart';

/// What kind of element is currently selected.
enum SelectionKind { clef, keySig, timeSig, note }

enum AudioStatus { idle, preloading, ready, error }

/// Central state manager for the score editor.
class ScoreNotifier extends ChangeNotifier {
  static const double _epsilon = 0.001;
  static const Duration _draftSaveDelay = Duration(milliseconds: 250);

  ScoreNotifier({
    AudioService? audioService,
    WorkspaceRepository? workspaceRepository,
    ScoreLibraryRepository? scoreLibraryRepository,
    PresetScoreRepository? presetScoreRepository,
  }) : _audioService = audioService ?? AudioService(),
       _workspaceRepository =
           workspaceRepository ??
           DefaultWorkspaceRepository(
             scoreLibraryRepository: scoreLibraryRepository,
             presetScoreRepository: presetScoreRepository,
           ) {
    _workspaceSession = WorkspaceSession(
      editorScore: score.copy(),
      document: WorkspaceDocument.draft(score: score),
      savedScores: const [],
      presetScores: const [],
    );
    _audioService.onStateChanged = _syncAudioState;
    _syncAudioState(notify: false);
  }

  final Score score = Score();
  final AudioService _audioService;
  final WorkspaceRepository _workspaceRepository;

  Future<void>? _initFuture;
  Timer? _draftSaveTimer;
  WorkspaceSession? _workspaceSession;
  bool _initialWorkspaceLoadComplete = false;
  bool _initialWorkspaceLoadSucceeded = false;

  /// Index where the next note will be inserted.
  int _cursorIndex = 0;
  int get cursorIndex => _cursorIndex;

  /// What kind of element is selected. Null = cursor at end (input mode).
  SelectionKind? _selectionKind;
  SelectionKind? get selectionKind => _selectionKind;

  /// Currently selected note index (valid only when [_selectionKind] == note).
  int? _selectedNoteIndex;
  int? get selectedIndex =>
      _selectionKind == SelectionKind.note ? _selectedNoteIndex : null;

  Note? get selectedNote {
    final index = selectedIndex;
    if (index == null) return null;
    return score.notes[index];
  }

  /// Active duration for future note input.
  NoteDuration _currentDuration = NoteDuration.quarter;
  NoteDuration get currentDuration => _currentDuration;

  /// Whether rest mode is active for the next input.
  bool _restMode = false;
  bool get restMode => _restMode;

  /// Whether dotted mode is active for the next input.
  bool _dottedMode = false;
  bool get dottedMode => _dottedMode;

  /// Whether the next inserted pitched note should slur to its successor.
  bool _slurMode = false;
  bool get slurMode => _slurMode;

  /// Whether the next inserted input should become a complete triplet.
  bool _tripletMode = false;
  bool get tripletMode => _tripletMode;

  KeyboardInputMode _keyboardInputMode = KeyboardInputMode.keySignatureAware;
  KeyboardInputMode get keyboardInputMode => _keyboardInputMode;

  int _keyboardOctaveShift = 0;
  int get keyboardOctaveShift => _keyboardOctaveShift;
  bool get canShiftKeyboardMappingDown =>
      _keyboardOctaveShift > _keyboardShiftBounds.minShift;
  bool get canShiftKeyboardMappingUp =>
      _keyboardOctaveShift < _keyboardShiftBounds.maxShift;
  KeyboardShiftBounds get _keyboardShiftBounds =>
      keyboardShiftBoundsForClef(score.clef);

  /// Auto-incrementing triplet group ID.
  int _nextTripletGroupId = 1;

  List<SavedScoreEntry> get savedScores =>
      List.unmodifiable(_workspaceSession?.savedScores ?? const []);

  List<PresetScoreEntry> get presetScores =>
      List.unmodifiable(_workspaceSession?.presetScores ?? const []);

  String? get activeScoreId => _workspaceSession?.document.savedScoreId;

  String? get activePresetId => _workspaceSession?.document.presetId;

  SavedScoreEntry? get activeSavedScore {
    final id = activeScoreId;
    if (id == null) return null;
    for (final entry in savedScores) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  PresetScoreEntry? get activePresetScore {
    final id = activePresetId;
    if (id == null) return null;
    for (final entry in presetScores) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  String get currentScoreLabel => _workspaceSession?.document.name ?? 'Draft';

  bool _hasUnsavedChanges = false;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  String? _libraryMessage;
  String? get libraryMessage => _libraryMessage;

  bool _libraryMessageIsError = false;
  bool get libraryMessageIsError => _libraryMessageIsError;

  Timer? _libraryMessageTimer;

  /// Selection-aware toolbar state.
  bool get timingControlsEnabled =>
      _selectionKind == null || _selectionKind == SelectionKind.note;
  NoteDuration get toolbarDuration =>
      selectedNote?.duration ?? _currentDuration;
  bool get toolbarShowsRestDurations => switch (_selectionKind) {
    SelectionKind.note => selectedNote?.isRest ?? false,
    null => _restMode,
    _ => false,
  };
  bool get toolbarRestSelected => switch (_selectionKind) {
    SelectionKind.note => selectedNote?.isRest ?? false,
    null => _restMode,
    _ => false,
  };
  bool get toolbarDottedSelected => switch (_selectionKind) {
    SelectionKind.note => selectedNote?.isDotted ?? false,
    null => _dottedMode,
    _ => false,
  };
  bool get toolbarSlurSelected => switch (_selectionKind) {
    SelectionKind.note => selectedNote?.slurToNext ?? false,
    null => _slurMode,
    _ => false,
  };
  bool get toolbarTripletSelected => switch (_selectionKind) {
    SelectionKind.note => _selectedValidTripletGroupIndices != null,
    null => _tripletMode,
    _ => false,
  };
  bool get durationButtonsEnabled {
    if (!timingControlsEnabled) {
      return false;
    }
    return !_selectedTripletRequiresLockedDuration;
  }

  bool get slurButtonEnabled {
    if (_selectionKind == null) {
      return _cursorIndex >= score.notes.length ||
          !score.notes[_cursorIndex].isRest;
    }
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return false;
    }
    final selected = score.notes[_selectedNoteIndex!];
    if (selected.isRest) return false;
    if (_selectedNoteIndex! >= score.notes.length - 1) return true;
    return !score.notes[_selectedNoteIndex! + 1].isRest;
  }

  bool get tripletButtonEnabled {
    if (_selectionKind == null) return true;
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return false;
    }
    return _selectedValidTripletGroupIndices != null ||
        _canCreateTripletFromSelection(_selectedNoteIndex!);
  }

  bool get deleteButtonEnabled {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      return true;
    }
    return _selectionKind == null &&
        _cursorIndex == score.notes.length &&
        score.notes.isNotEmpty;
  }

  /// Playback state.
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Index of the note currently being played.
  int _playbackIndex = -1;
  int get playbackIndex => _playbackIndex;

  /// Whether the audio engine is initialized.
  AudioStatus _audioStatus = AudioStatus.idle;
  AudioStatus get audioStatus => _audioStatus;
  bool get isInitialized => _audioStatus == AudioStatus.ready;
  String? _audioStatusMessage;
  String? get audioStatusMessage => _audioStatusMessage;
  bool get audioStatusIsError => _audioStatus == AudioStatus.error;
  bool get initialWorkspaceLoadComplete => _initialWorkspaceLoadComplete;
  bool get initialWorkspaceLoadSucceeded => _initialWorkspaceLoadSucceeded;

  /// Initialize local storage and the editor entry state.
  Future<void> init({ScoreSeedConfig? initialScoreConfig}) {
    return _initFuture ??= _initInternal(
      initialScoreConfig: initialScoreConfig,
    );
  }

  Future<void> _initInternal({ScoreSeedConfig? initialScoreConfig}) async {
    try {
      final result = await _workspaceRepository.loadWorkspace(
        initialScoreConfig: initialScoreConfig,
      );
      _applyWorkspaceLoadResult(result, replaceScore: true);
      _initialWorkspaceLoadSucceeded = true;
      if (initialScoreConfig != null && !initialScoreConfig.isRestore) {
        unawaited(_persistInitializedWorkspace(result.workspace));
      }
    } on WorkspaceRepositoryException catch (error) {
      _initialWorkspaceLoadSucceeded = false;
      _setLibraryMessage(error.message, isError: true);
    } on PresetScoreException catch (error) {
      _initialWorkspaceLoadSucceeded = false;
      _setLibraryMessage(error.message, isError: true);
    } on ScoreLibraryStorageException catch (error) {
      _initialWorkspaceLoadSucceeded = false;
      _setLibraryMessage(error.message, isError: true);
    } catch (error) {
      _initialWorkspaceLoadSucceeded = false;
      _setLibraryMessage('Failed to load the workspace.', isError: true);
      debugPrint('Workspace load failed: $error');
    }

    _initialWorkspaceLoadComplete = true;
    notifyListeners();
  }

  WorkspaceSession get _requiredWorkspace {
    final workspace = _workspaceSession;
    if (workspace == null) {
      throw StateError('Workspace has not been initialized.');
    }
    return workspace;
  }

  bool _applyWorkspaceLoadResult(
    WorkspaceLoadResult result, {
    required bool replaceScore,
  }) {
    _replaceWorkspace(result.workspace, replaceScore: replaceScore);
    final warningMessage = result.warningMessage;
    if (warningMessage == null) {
      return false;
    }
    _setLibraryMessage(warningMessage, isError: true);
    return true;
  }

  void _replaceWorkspace(
    WorkspaceSession workspace, {
    required bool replaceScore,
  }) {
    _workspaceSession = workspace;
    if (replaceScore) {
      _applyScore(workspace.editorScore);
    }
    _hasUnsavedChanges = _computeHasUnsavedChanges(score);
  }

  Future<void> _persistInitializedWorkspace(WorkspaceSession workspace) async {
    try {
      await _workspaceRepository.persistDraft(
        workspace: workspace,
        editedScore: workspace.editorScore,
      );
    } on ScoreLibraryStorageException catch (error) {
      _setLibraryMessage(error.message, isError: true);
      notifyListeners();
    }
  }

  void _syncAudioState({bool notify = true}) {
    final previousStatus = _audioStatus;
    final previousMessage = _audioStatusMessage;

    switch (_audioService.initializationState) {
      case AudioInitializationState.idle:
        _audioStatus = AudioStatus.idle;
        _audioStatusMessage = null;
      case AudioInitializationState.loading:
        _audioStatus = AudioStatus.preloading;
        _audioStatusMessage = 'Preparing piano audio…';
      case AudioInitializationState.ready:
        _audioStatus = AudioStatus.ready;
        _audioStatusMessage = null;
      case AudioInitializationState.error:
        _audioStatus = AudioStatus.error;
        _audioStatusMessage =
            _audioService.initializationError ??
            'Piano audio failed to initialize.';
    }

    if (notify &&
        (previousStatus != _audioStatus ||
            previousMessage != _audioStatusMessage)) {
      notifyListeners();
    }
  }

  double get _measureDuration => score.beatsPerMeasure * (4.0 / score.beatUnit);

  List<int>? get _selectedValidTripletGroupIndices {
    final index = selectedIndex;
    if (index == null) return null;
    final groupId = score.notes[index].tripletGroupId;
    if (groupId == null) return null;
    final indices = _validTripletGroupIndices(groupId);
    if (indices == null || !indices.contains(index)) return null;
    return indices;
  }

  bool get _selectedTripletRequiresLockedDuration {
    final selectedTriplet = _selectedValidTripletGroupIndices;
    final selectedIndex = _selectedNoteIndex;
    if (selectedTriplet == null || selectedIndex == null) {
      return false;
    }
    return selectedIndex != selectedTriplet.last;
  }

  bool get _selectedTripletCanExtendWithTie {
    final selectedTriplet = _selectedValidTripletGroupIndices;
    final selectedIndex = _selectedNoteIndex;
    if (selectedTriplet == null || selectedIndex == null) {
      return false;
    }
    return selectedIndex == selectedTriplet.last;
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
      stop();
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
        workspace: _requiredWorkspace,
        editedScore: score,
        name: trimmedName,
        createNew: createNew,
      );
      _replaceWorkspace(workspace, replaceScore: false);
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
      stop();
      final workspace = await _workspaceRepository.loadSavedScore(
        workspace: _requiredWorkspace,
        id: id,
      );
      _replaceWorkspace(workspace, replaceScore: true);
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
      stop();
      final workspace = await _workspaceRepository.loadPresetScore(
        workspace: _requiredWorkspace,
        id: id,
      );
      _replaceWorkspace(workspace, replaceScore: true);
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
      stop();
      final workspace = await _workspaceRepository.importDocument(
        workspace: _requiredWorkspace,
        document: document,
      );
      _replaceWorkspace(workspace, replaceScore: true);
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
      score: score.copy(),
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
        workspace: _requiredWorkspace,
        id: id,
        currentScore: score,
      );
      _replaceWorkspace(workspace, replaceScore: false);
      _setLibraryMessage('Deleted "${removedEntry.name}".', isError: false);
    } on ScoreLibraryStorageException catch (error) {
      _setLibraryMessage(error.message, isError: true);
    }

    notifyListeners();
  }

  /// Set the active duration for future input, or edit the selected note/rest.
  void setDuration(NoteDuration duration) {
    if (!durationButtonsEnabled) return;

    _currentDuration = duration;

    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      changeSelectedDuration(duration);
      return;
    }

    if (_restMode) {
      _insertRestAtCursor(duration: duration);
      _restMode = false;
      _notifyScoreChanged();
      return;
    }

    notifyListeners();
  }

  /// Enter rest mode in input state or toggle the selected note/rest.
  void handleRestAction() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      final index = _selectedNoteIndex!;
      final old = score.notes[index];
      final updated = old.isRest
          ? old.asPitched(defaultMidi: score.clef.defaultRestoreMidi)
          : old.asRest();
      score.replaceAt(index, updated);
      _sanitizeSlursInRange(index - 1, index);
      _currentDuration = updated.duration;
      _dottedMode = updated.isDotted;

      if (!updated.isRest) {
        _audioService.playNoteWithDuration(
          updated.midi,
          duration: const Duration(milliseconds: 500),
        );
      }

      _notifyScoreChanged();
      return;
    }

    if (_selectionKind != null) {
      return;
    }

    _restMode = !_restMode;
    notifyListeners();
  }

  /// Toggle dotted mode for the next input or the selected note/triplet group.
  void toggleDottedMode() {
    if (!timingControlsEnabled) return;

    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      toggleSelectedDotted();
      return;
    }

    _dottedMode = !_dottedMode;
    notifyListeners();
  }

  /// Toggle slur input mode or edit the selected note.
  void toggleSlurMode() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      if (!slurButtonEnabled) return;
      final index = _selectedNoteIndex!;
      final note = score.notes[index];
      score.replaceAt(index, note.copyWith(slurToNext: !note.slurToNext));
      _sanitizeSlursInRange(index - 1, index);
      _notifyScoreChanged();
      return;
    }

    if (_selectionKind != null || !slurButtonEnabled) {
      return;
    }

    _slurMode = !_slurMode;
    notifyListeners();
  }

  /// Toggle triplet input mode or edit the selected note group.
  void toggleTripletMode() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      final selectedTriplet = _selectedValidTripletGroupIndices;
      if (selectedTriplet != null) {
        for (final index in selectedTriplet) {
          final note = score.notes[index];
          score.replaceAt(
            index,
            note.copyWith(tripletGroupId: () => null, slurToNext: false),
          );
        }
        _sanitizeSlursInRange(selectedTriplet.first - 1, selectedTriplet.last);
        _notifyScoreChanged();
        return;
      }

      if (!tripletButtonEnabled) {
        return;
      }

      _createTripletFromSelection(_selectedNoteIndex!);
      _notifyScoreChanged();
      return;
    }

    if (_selectionKind != null) {
      return;
    }

    _tripletMode = !_tripletMode;
    notifyListeners();
  }

  void _insertNotesAtCursor(List<Note> notes) {
    final startIndex = _cursorIndex;
    for (final note in notes) {
      score.addNote(note, _cursorIndex);
      _cursorIndex++;
    }
    _sanitizeSlursInRange(startIndex - 1, _cursorIndex - 1);

    _selectionKind = null;
    _selectedNoteIndex = null;

    Note? soundedNote;
    for (final note in notes) {
      if (!note.isRest) {
        soundedNote = note;
        break;
      }
    }
    if (soundedNote != null) {
      _audioService.playNoteWithDuration(
        soundedNote.midi,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  List<Note> _expandForPendingTriplet(Note prototype) {
    if (!_tripletMode) {
      return [prototype];
    }

    final tripletGroupId = _nextTripletGroupId++;
    _tripletMode = false;

    return List<Note>.generate(3, (index) {
      return prototype.copyWith(
        tripletGroupId: () => tripletGroupId,
        slurToNext: prototype.slurToNext && index == 2,
      );
    }, growable: false);
  }

  void _insertRestAtCursor({NoteDuration? duration}) {
    final prototype = Note.rest(
      duration: duration ?? _currentDuration,
      isDotted: _dottedMode,
    );
    _insertNotesAtCursor(_expandForPendingTriplet(prototype));
  }

  int resolveInputMidi(int rawMidi) {
    return switch (_keyboardInputMode) {
      KeyboardInputMode.keySignatureAware => score.keySignature.applyToMidi(
        rawMidi,
      ),
      KeyboardInputMode.chromatic => rawMidi,
    };
  }

  bool canTapPianoKey(int midi) {
    if (_keyboardInputMode == KeyboardInputMode.chromatic) {
      return true;
    }
    return !isBlackMidi(midi);
  }

  void handlePianoTap(int midi) {
    if (!canTapPianoKey(midi)) {
      return;
    }

    final resolvedMidi = switch (_keyboardInputMode) {
      KeyboardInputMode.keySignatureAware => score.keySignature.applyToMidi(
        midi,
      ),
      KeyboardInputMode.chromatic => midi,
    };
    insertPitchedNote(resolvedMidi);
  }

  void toggleKeyboardInputMode() {
    _keyboardInputMode = switch (_keyboardInputMode) {
      KeyboardInputMode.keySignatureAware => KeyboardInputMode.chromatic,
      KeyboardInputMode.chromatic => KeyboardInputMode.keySignatureAware,
    };
    notifyListeners();
  }

  void shiftKeyboardMapping(int direction) {
    final nextShift = _keyboardShiftBounds.clamp(
      _keyboardOctaveShift + direction,
    );
    if (nextShift == _keyboardOctaveShift) {
      return;
    }
    _keyboardOctaveShift = nextShift;
    notifyListeners();
  }

  void handleEditorShortcut(EditorShortcutIntent shortcut) {
    switch (shortcut.kind) {
      case EditorShortcutKind.insertPitch:
        insertPitchedNote(resolveInputMidi(shortcut.midi!));
      case EditorShortcutKind.restAction:
        handleRestAction();
      case EditorShortcutKind.setDuration:
        setDuration(shortcut.duration!);
      case EditorShortcutKind.toggleDotted:
        toggleDottedMode();
      case EditorShortcutKind.toggleSlur:
        toggleSlurMode();
      case EditorShortcutKind.toggleTriplet:
        toggleTripletMode();
      case EditorShortcutKind.shiftDown:
        shiftKeyboardMapping(-1);
      case EditorShortcutKind.shiftUp:
        shiftKeyboardMapping(1);
      case EditorShortcutKind.toggleInputMode:
        toggleKeyboardInputMode();
    }
  }

  /// Insert a pitched note at the cursor position.
  void insertPitchedNote(int midi) {
    if (_restMode) {
      _restMode = false;
    }

    final prototype = Note(
      midi: midi,
      duration: _currentDuration,
      isDotted: _dottedMode,
      slurToNext: _slurMode,
    );
    _slurMode = false;

    _insertNotesAtCursor(_expandForPendingTriplet(prototype));
    _notifyScoreChanged();
  }

  /// Select a note at the given index, or deselect (cursor at end) when null.
  void selectNote(int? index) {
    if (index != null && (index < 0 || index >= score.notes.length)) return;
    _restMode = false;

    if (index != null) {
      _selectionKind = SelectionKind.note;
      _selectedNoteIndex = index;
      _cursorIndex = index + 1;

      final note = score.notes[index];
      if (!note.isRest) {
        _audioService.playNoteWithDuration(
          note.midi,
          duration: const Duration(milliseconds: 500),
        );
      }
    } else {
      _selectionKind = null;
      _selectedNoteIndex = null;
      _cursorIndex = score.notes.length;
    }
    notifyListeners();
  }

  /// Select the time signature element.
  void selectTimeSig() {
    _restMode = false;
    _selectionKind = SelectionKind.timeSig;
    _selectedNoteIndex = null;
    _cursorIndex = 0;
    notifyListeners();
  }

  /// Select the key signature element.
  void selectKeySig() {
    _restMode = false;
    _selectionKind = SelectionKind.keySig;
    _selectedNoteIndex = null;
    _cursorIndex = 0;
    notifyListeners();
  }

  /// Select the clef element.
  void selectClef() {
    _restMode = false;
    _selectionKind = SelectionKind.clef;
    _selectedNoteIndex = null;
    _cursorIndex = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Navigation (← / →)
  // ---------------------------------------------------------------------------

  /// Move selection one step to the left.
  /// Order: cursor(end) → note[n-1] → ... → note[0] → timeSig → keySig → clef
  void moveSelectionLeft() {
    switch (_selectionKind) {
      case null:
        if (score.notes.isNotEmpty) {
          selectNote(score.notes.length - 1);
        } else {
          selectTimeSig();
        }
      case SelectionKind.note:
        final idx = _selectedNoteIndex ?? 0;
        if (idx > 0) {
          selectNote(idx - 1);
        } else {
          selectTimeSig();
        }
      case SelectionKind.timeSig:
        selectKeySig();
      case SelectionKind.keySig:
        selectClef();
      case SelectionKind.clef:
        break;
    }
  }

  /// Move selection one step to the right.
  /// Order: clef → keySig → timeSig → note[0] → ... → note[n-1] → cursor(end)
  void moveSelectionRight() {
    switch (_selectionKind) {
      case SelectionKind.clef:
        selectKeySig();
      case SelectionKind.keySig:
        selectTimeSig();
      case SelectionKind.timeSig:
        if (score.notes.isNotEmpty) {
          selectNote(0);
        } else {
          selectNote(null);
        }
      case SelectionKind.note:
        final idx = _selectedNoteIndex ?? 0;
        if (idx < score.notes.length - 1) {
          selectNote(idx + 1);
        } else {
          selectNote(null);
        }
      case null:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Adjust selected element (↑ / ↓)
  // ---------------------------------------------------------------------------

  /// Adjust the selected element up (+1) or down (-1).
  void adjustSelection(int direction) {
    switch (_selectionKind) {
      case SelectionKind.clef:
        cycleClef(direction);
      case SelectionKind.keySig:
        shiftKeySignature(direction);
      case SelectionKind.timeSig:
        cycleTimeSignature(direction);
      case SelectionKind.note:
        _diatonicStepSelected(direction);
      case null:
        break;
    }
  }

  /// Move the selected note by one diatonic step.
  void _diatonicStepSelected(int direction) {
    if (_selectedNoteIndex == null) return;
    final note = score.notes[_selectedNoteIndex!];
    if (note.isRest) return;
    final newMidi = score.keySignature.diatonicStep(note.midi, direction);
    if (newMidi == note.midi) return;
    score.replaceAt(
      _selectedNoteIndex!,
      note.copyWith(midi: newMidi, sourceMidi: () => null),
    );
    _audioService.playNoteWithDuration(
      newMidi,
      duration: const Duration(milliseconds: 500),
    );
    _notifyScoreChanged();
  }

  /// Delete the currently selected note, or the last note in end-input mode.
  void deleteSelected() {
    if (_selectionKind == SelectionKind.note && _selectedNoteIndex != null) {
      _deleteNoteAtIndex(_selectedNoteIndex!, keepSelection: true);
      _notifyScoreChanged();
      return;
    }

    if (_selectionKind == null &&
        _cursorIndex == score.notes.length &&
        score.notes.isNotEmpty) {
      _deleteNoteAtIndex(score.notes.length - 1, keepSelection: false);
      _notifyScoreChanged();
    }
  }

  void _deleteNoteAtIndex(int removedIndex, {required bool keepSelection}) {
    final previousIndex = removedIndex - 1;
    final tripletGroupId = score.notes[removedIndex].tripletGroupId;
    final tripletGroup = tripletGroupId == null
        ? null
        : _validTripletGroupIndices(tripletGroupId);
    score.removeAt(removedIndex);

    if (tripletGroup != null) {
      for (final originalIndex in tripletGroup.where(
        (i) => i != removedIndex,
      )) {
        final shiftedIndex = originalIndex > removedIndex
            ? originalIndex - 1
            : originalIndex;
        if (shiftedIndex >= 0 && shiftedIndex < score.notes.length) {
          final note = score.notes[shiftedIndex];
          score.replaceAt(
            shiftedIndex,
            note.copyWith(tripletGroupId: () => null, slurToNext: false),
          );
        }
      }
    }
    if (previousIndex >= 0 && previousIndex < score.notes.length) {
      final previous = score.notes[previousIndex];
      if (previous.slurToNext) {
        score.replaceAt(previousIndex, previous.copyWith(slurToNext: false));
      }
    }
    _sanitizeSlursInRange(removedIndex - 1, removedIndex);

    if (_cursorIndex > removedIndex) {
      _cursorIndex--;
    }

    if (!keepSelection) {
      _selectionKind = null;
      _selectedNoteIndex = null;
      _cursorIndex = score.notes.length;
      return;
    }

    if (score.notes.isEmpty) {
      _selectionKind = null;
      _selectedNoteIndex = null;
      _cursorIndex = 0;
      return;
    }

    _selectionKind = SelectionKind.note;
    _selectedNoteIndex = removedIndex >= score.notes.length
        ? score.notes.length - 1
        : removedIndex;
    _cursorIndex = _selectedNoteIndex! + 1;
  }

  /// Change the pitch of the selected note.
  void changeSelectedPitch(int midi) {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return;
    }
    final old = score.notes[_selectedNoteIndex!];
    score.replaceAt(
      _selectedNoteIndex!,
      old.copyWith(midi: midi, sourceMidi: () => null),
    );

    _audioService.playNoteWithDuration(
      midi,
      duration: const Duration(milliseconds: 500),
    );

    _notifyScoreChanged();
  }

  /// Change the duration of the selected note.
  void changeSelectedDuration(NoteDuration duration) {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return;
    }

    _currentDuration = duration;
    if (_selectedTripletCanExtendWithTie) {
      _createOrUpdateTripletTieContinuation(duration);
      _notifyScoreChanged();
      return;
    }
    _applyDurationOrDotToSelectedGroup(
      (note) => note.copyWith(duration: duration),
    );
    _notifyScoreChanged();
  }

  /// Toggle the dotted flag on the selected note.
  void toggleSelectedDotted() {
    if (_selectionKind != SelectionKind.note || _selectedNoteIndex == null) {
      return;
    }

    final nextValue = !score.notes[_selectedNoteIndex!].isDotted;
    _dottedMode = nextValue;
    _applyDurationOrDotToSelectedGroup(
      (note) => note.copyWith(isDotted: nextValue),
    );
    _notifyScoreChanged();
  }

  void _applyDurationOrDotToSelectedGroup(Note Function(Note note) transform) {
    final selectedTriplet = _selectedValidTripletGroupIndices;
    if (selectedTriplet != null) {
      for (final index in selectedTriplet) {
        score.replaceAt(index, transform(score.notes[index]));
      }
      return;
    }

    final index = _selectedNoteIndex;
    if (index == null) return;
    score.replaceAt(index, transform(score.notes[index]));
  }

  void _createOrUpdateTripletTieContinuation(NoteDuration duration) {
    final index = _selectedNoteIndex;
    if (index == null) {
      return;
    }
    final source = score.notes[index];
    if (source.isRest) {
      return;
    }

    final continuationIndex = index + 1;
    score.replaceAt(index, source.copyWith(slurToNext: true));

    final existingContinuation = continuationIndex < score.notes.length
        ? score.notes[continuationIndex]
        : null;
    if (existingContinuation != null &&
        existingContinuation.tripletGroupId == null &&
        !existingContinuation.isRest &&
        existingContinuation.midi == source.midi) {
      score.replaceAt(
        continuationIndex,
        existingContinuation.copyWith(
          duration: duration,
          sourceMidi: () => null,
        ),
      );
    } else {
      score.addNote(
        source.copyWith(
          duration: duration,
          tripletGroupId: () => null,
          slurToNext: false,
          sourceMidi: () => null,
        ),
        continuationIndex,
      );
    }

    _selectedNoteIndex = continuationIndex;
    _cursorIndex = continuationIndex + 1;
    _sanitizeSlursInRange(index, continuationIndex);
  }

  void _sanitizeSlursInRange(int start, int end) {
    if (score.notes.isEmpty) return;
    final lower = start.clamp(0, score.notes.length - 1);
    final upper = end.clamp(0, score.notes.length - 1);
    if (lower > upper) return;
    for (var index = lower; index <= upper; index++) {
      _sanitizeSlurAt(index);
    }
  }

  void _sanitizeSlurAt(int index) {
    if (index < 0 || index >= score.notes.length) return;
    final note = score.notes[index];
    final hasNext = index + 1 < score.notes.length;
    final nextIsRest = hasNext && score.notes[index + 1].isRest;
    if (note.slurToNext && (note.isRest || nextIsRest)) {
      score.replaceAt(index, note.copyWith(slurToNext: false));
    }
  }

  int? _nextTripletStartIndex(int selectedIndex) {
    if (selectedIndex == score.notes.length - 1) {
      return selectedIndex;
    }

    if (selectedIndex + 2 >= score.notes.length) {
      return null;
    }

    return selectedIndex;
  }

  bool _canCreateTripletFromSelection(int selectedIndex) {
    final startIndex = _nextTripletStartIndex(selectedIndex);
    if (startIndex == null) return false;

    final selected = score.notes[selectedIndex];
    if (selected.tripletGroupId != null) return false;

    if (selectedIndex == score.notes.length - 1) {
      return _tripletFitsAt(startIndex, selected.writtenBeats);
    }

    final candidates = score.notes.sublist(startIndex, startIndex + 3);
    final first = candidates.first;

    if (candidates.any((note) => note.tripletGroupId != null)) {
      return false;
    }

    if (candidates.any(
      (note) =>
          note.duration != first.duration || note.isDotted != first.isDotted,
    )) {
      return false;
    }

    return _tripletFitsAt(startIndex, first.writtenBeats);
  }

  bool _tripletFitsAt(int startIndex, double writtenBeats) {
    final beatsBefore = _beatsBeforeIndex(startIndex);
    final beatInMeasure = beatsBefore % _measureDuration;
    final tripletBeats = writtenBeats * 2.0;
    return beatInMeasure + tripletBeats <= _measureDuration + _epsilon;
  }

  double _beatsBeforeIndex(int index) {
    var beats = 0.0;
    for (var i = 0; i < index; i++) {
      beats += score.notes[i].effectiveBeats;
    }
    return beats;
  }

  List<int>? _validTripletGroupIndices(int groupId) {
    final indices = <int>[];

    for (var i = 0; i < score.notes.length; i++) {
      if (score.notes[i].tripletGroupId == groupId) {
        indices.add(i);
      }
    }

    if (indices.length != 3) return null;

    for (var i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) return null;
    }

    final first = score.notes[indices.first];
    if (indices.any((index) {
      final note = score.notes[index];
      return note.duration != first.duration || note.isDotted != first.isDotted;
    })) {
      return null;
    }

    return indices;
  }

  void _createTripletFromSelection(int selectedIndex) {
    final source = score.notes[selectedIndex];
    final tripletGroupId = _nextTripletGroupId++;

    score.replaceAt(
      selectedIndex,
      source.copyWith(tripletGroupId: () => tripletGroupId, slurToNext: false),
    );

    if (selectedIndex == score.notes.length - 1) {
      final cloneA = source.copyWith(
        tripletGroupId: () => tripletGroupId,
        slurToNext: false,
      );
      final cloneB = source.copyWith(
        tripletGroupId: () => tripletGroupId,
        slurToNext: false,
      );
      score.addNote(cloneA, selectedIndex + 1);
      score.addNote(cloneB, selectedIndex + 2);
      _sanitizeSlursInRange(selectedIndex - 1, selectedIndex + 2);
      return;
    }

    for (var i = selectedIndex + 1; i <= selectedIndex + 2; i++) {
      final note = score.notes[i];
      score.replaceAt(
        i,
        note.copyWith(tripletGroupId: () => tripletGroupId, slurToNext: false),
      );
    }
    _sanitizeSlursInRange(selectedIndex - 1, selectedIndex + 2);
  }

  /// Move cursor to a specific index.
  void moveCursor(int index) {
    _cursorIndex = index.clamp(0, score.notes.length);
    notifyListeners();
  }

  /// Start playing the score from the beginning.
  Future<void> play() async {
    if (score.notes.isEmpty || _isPlaying) return;

    _isPlaying = true;
    _playbackIndex = 0;
    notifyListeners();

    await _audioService.playScore(
      score,
      onNoteIndex: (index) {
        _playbackIndex = index;
        notifyListeners();
      },
      onComplete: () {
        _isPlaying = false;
        _playbackIndex = -1;
        notifyListeners();
      },
    );
  }

  /// Stop playback.
  void stop() {
    _audioService.stopPlayback();
    _isPlaying = false;
    _playbackIndex = -1;
    notifyListeners();
  }

  /// Set tempo (BPM).
  void setTempo(double bpm) {
    final nextBpm = bpm.clamp(40, 240).toDouble();
    if (score.bpm == nextBpm) {
      return;
    }
    score.bpm = nextBpm;
    _notifyScoreChanged();
  }

  // ---------------------------------------------------------------------------
  // Time signature
  // ---------------------------------------------------------------------------

  /// Set clef explicitly.
  void setClef(Clef clef) {
    if (score.clef == clef) {
      return;
    }
    score.clef = clef;
    _keyboardOctaveShift = _keyboardShiftBounds.clamp(_keyboardOctaveShift);
    _notifyScoreChanged();
  }

  /// Toggle between treble and bass clef.
  void cycleClef(int direction) {
    if (direction == 0) {
      return;
    }
    final next = score.clef == Clef.treble ? Clef.bass : Clef.treble;
    setClef(next);
  }

  /// Set time signature (e.g. 3/4, 6/8).
  void setTimeSignature(int beats, int unit) {
    final nextBeats = beats.clamp(1, 16);
    if (score.beatsPerMeasure == nextBeats && score.beatUnit == unit) {
      return;
    }
    score.beatsPerMeasure = nextBeats;
    score.beatUnit = unit;
    _notifyScoreChanged();
  }

  /// Cycle through common time signatures.
  void cycleTimeSignature(int direction) {
    final current = (score.beatsPerMeasure, score.beatUnit);
    final idx = commonTimeSignatures.indexOf(current);
    final next = idx < 0
        ? 0
        : (idx + direction).clamp(0, commonTimeSignatures.length - 1);
    final (beats, unit) = commonTimeSignatures[next];
    setTimeSignature(beats, unit);
  }

  // ---------------------------------------------------------------------------
  // Key signature
  // ---------------------------------------------------------------------------

  /// Set key signature explicitly.
  void setKeySignature(KeySignature key) {
    final previousKey = score.keySignature;
    if (previousKey == key) {
      return;
    }

    for (var index = 0; index < score.notes.length; index++) {
      final note = score.notes[index];
      if (note.isRest) {
        continue;
      }
      score.replaceAt(
        index,
        note.copyWith(midi: previousKey.remapTo(key, note.midi)),
      );
    }
    score.keySignature = key;
    _notifyScoreChanged();
  }

  /// Shift key signature one step on the circle of fifths.
  /// [direction] > 0 = add sharp (clockwise), < 0 = add flat (counter-clockwise).
  void shiftKeySignature(int direction) {
    final next = direction > 0
        ? score.keySignature.nextSharp
        : score.keySignature.nextFlat;
    setKeySignature(next);
  }

  void _notifyScoreChanged() {
    _hasUnsavedChanges = _computeHasUnsavedChanges(score);
    _scheduleDraftSave();
    notifyListeners();
  }

  void _scheduleDraftSave() {
    if (_initFuture == null) {
      return;
    }
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDelay, () async {
      try {
        await _workspaceRepository.persistDraft(
          workspace: _requiredWorkspace,
          editedScore: score,
        );
      } on ScoreLibraryStorageException {
        notifyListeners();
      }
    });
  }

  void _applyScore(Score source) {
    score.notes
      ..clear()
      ..addAll(source.notes);
    score.beatsPerMeasure = source.beatsPerMeasure;
    score.beatUnit = source.beatUnit;
    score.bpm = source.bpm;
    score.clef = source.clef;
    score.keySignature = source.keySignature;
    _keyboardOctaveShift = _keyboardShiftBounds.clamp(_keyboardOctaveShift);

    _selectionKind = null;
    _selectedNoteIndex = null;
    _cursorIndex = score.notes.length;
    _currentDuration = NoteDuration.quarter;
    _restMode = false;
    _dottedMode = false;
    _slurMode = false;
    _tripletMode = false;
    _syncNextTripletGroupId();
  }

  void _syncNextTripletGroupId() {
    var maxTripletGroupId = 0;
    for (final note in score.notes) {
      final groupId = note.tripletGroupId;
      if (groupId != null && groupId > maxTripletGroupId) {
        maxTripletGroupId = groupId;
      }
    }
    _nextTripletGroupId = maxTripletGroupId + 1;
  }

  bool _computeHasUnsavedChanges(Score candidate) {
    final baseline = _workspaceSession?.document.score;
    if (baseline == null) {
      return false;
    }
    return candidate != baseline;
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
    _libraryMessageTimer?.cancel();
    _draftSaveTimer?.cancel();
    stop();
    _audioService.onStateChanged = null;
    _audioService.dispose();
    super.dispose();
  }
}
