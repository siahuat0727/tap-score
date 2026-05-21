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
import '../workspace/workspace_repository.dart';
import '../workspace/workspace_session.dart';
import 'editable_score_session.dart';
import 'editor_controller.dart';
import 'playback_controller.dart' show AudioStatus, PlaybackController;
import 'score_library_controller.dart';

export 'editor_controller.dart' show SelectionKind;
export 'playback_controller.dart' show AudioStatus;

/// Compatibility facade for legacy widgets that have not migrated to the split
/// workspace controllers yet.
class ScoreNotifier extends ChangeNotifier {
  factory ScoreNotifier({
    AudioService? audioService,
    WorkspaceRepository? workspaceRepository,
    ScoreLibraryRepository? scoreLibraryRepository,
    PresetScoreRepository? presetScoreRepository,
  }) {
    final session = EditableScoreSession();
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    final editor = EditorController(session: session, notePreview: playback);
    final resolvedWorkspaceRepository =
        workspaceRepository ??
        DefaultWorkspaceRepository(
          scoreLibraryRepository: scoreLibraryRepository,
          presetScoreRepository: presetScoreRepository,
        );
    final library = ScoreLibraryController(
      session: session,
      playback: playback,
      workspaceRepository: resolvedWorkspaceRepository,
    );
    return ScoreNotifier._(
      session: session,
      playback: playback,
      editor: editor,
      library: library,
      ownsControllers: true,
    );
  }

  factory ScoreNotifier.compatibility({
    required EditableScoreSession session,
    required PlaybackController playback,
    required EditorController editor,
    required ScoreLibraryController library,
  }) {
    return ScoreNotifier._(
      session: session,
      playback: playback,
      editor: editor,
      library: library,
      ownsControllers: false,
    );
  }

  ScoreNotifier._({
    required EditableScoreSession session,
    required PlaybackController playback,
    required EditorController editor,
    required ScoreLibraryController library,
    required bool ownsControllers,
  }) : _session = session,
       _playback = playback,
       _editor = editor,
       _library = library,
       _ownsControllers = ownsControllers {
    _observedWorkspace = _session.workspace;
    _playback.addListener(_notifyFromOwnedController);
    _editor.addListener(_notifyFromOwnedController);
    _library.addListener(_notifyFromOwnedController);
  }

  final EditableScoreSession _session;
  final PlaybackController _playback;
  final EditorController _editor;
  final ScoreLibraryController _library;
  final bool _ownsControllers;
  late WorkspaceSession _observedWorkspace;
  bool _isDisposed = false;
  int _ownedControllerNotificationSuppressionDepth = 0;

  EditableScoreSession get session => _session;

  PlaybackController get playbackController => _playback;

  EditorController get editorController => _editor;

  ScoreLibraryController get scoreLibraryController => _library;

  Score get score => _session.score;

  int get cursorIndex => _editor.cursorIndex;

  SelectionKind? get selectionKind => _editor.selectionKind;

  int? get selectedIndex => _editor.selectedIndex;

  Note? get selectedNote => _editor.selectedNote;

  NoteDuration get currentDuration => _editor.currentDuration;

  bool get restMode => _editor.restMode;

  bool get dottedMode => _editor.dottedMode;

  bool get slurMode => _editor.slurMode;

  bool get tripletMode => _editor.tripletMode;

  KeyboardInputMode get keyboardInputMode => _editor.keyboardInputMode;

  int get keyboardOctaveShift => _editor.keyboardOctaveShift;

  bool get canShiftKeyboardMappingDown => _editor.canShiftKeyboardMappingDown;

  bool get canShiftKeyboardMappingUp => _editor.canShiftKeyboardMappingUp;

  List<SavedScoreEntry> get savedScores => _library.savedScores;

  List<PresetScoreEntry> get presetScores => _library.presetScores;

  String? get activeScoreId => _library.activeScoreId;

  String? get activePresetId => _library.activePresetId;

  SavedScoreEntry? get activeSavedScore => _library.activeSavedScore;

  PresetScoreEntry? get activePresetScore => _library.activePresetScore;

  String get currentScoreLabel => _library.currentScoreLabel;

  double get referenceBpm => _session.referenceBpm;

  bool get hasUnsavedChanges => _library.hasUnsavedChanges;

  String? get libraryMessage => _library.libraryMessage;

  bool get libraryMessageIsError => _library.libraryMessageIsError;

  bool get timingControlsEnabled => _editor.timingControlsEnabled;

  NoteDuration get toolbarDuration => _editor.toolbarDuration;

  bool get toolbarShowsRestDurations => _editor.toolbarShowsRestDurations;

  bool get toolbarRestSelected => _editor.toolbarRestSelected;

  bool get toolbarDottedSelected => _editor.toolbarDottedSelected;

  bool get toolbarSlurSelected => _editor.toolbarSlurSelected;

  bool get toolbarTripletSelected => _editor.toolbarTripletSelected;

  bool get durationButtonsEnabled => _editor.durationButtonsEnabled;

  bool get slurButtonEnabled => _editor.slurButtonEnabled;

  bool get tripletButtonEnabled => _editor.tripletButtonEnabled;

  bool get deleteButtonEnabled => _editor.deleteButtonEnabled;

  bool get isPlaying => _playback.isPlaying;

  int get playbackIndex => _playback.playbackIndex;

  AudioStatus get audioStatus => _playback.audioStatus;

  bool get isInitialized => _playback.isInitialized;

  String? get audioStatusMessage => _playback.audioStatusMessage;

  bool get audioStatusIsError => _playback.audioStatusIsError;

  bool get initialWorkspaceLoadComplete =>
      _library.initialWorkspaceLoadComplete;

  bool get initialWorkspaceLoadSucceeded =>
      _library.initialWorkspaceLoadSucceeded;

  Future<void> loadInitialWorkspace({
    ScoreSeedConfig? initialScoreConfig,
  }) async {
    await _runLibraryScoreReplacement(
      () =>
          _library.loadInitialWorkspace(initialScoreConfig: initialScoreConfig),
    );
  }

  void clearLibraryMessage() {
    _library.clearLibraryMessage();
  }

  void showLibraryMessage(String message, {required bool isError}) {
    _library.showLibraryMessage(message, isError: isError);
  }

  Future<void> restoreDraft() async {
    await _runLibraryScoreReplacement(_library.restoreDraft);
  }

  Future<void> saveCurrentScore(String name, {bool createNew = false}) async {
    await _library.saveCurrentScore(name, createNew: createNew);
  }

  Future<void> loadSavedScore(String id) async {
    await _runLibraryScoreReplacement(() => _library.loadSavedScore(id));
  }

  Future<void> loadPresetScore(String id) async {
    await _runLibraryScoreReplacement(() => _library.loadPresetScore(id));
  }

  Future<void> importScoreDocument(PortableScoreDocument document) async {
    await _runLibraryScoreReplacement(
      () => _library.importScoreDocument(document),
    );
  }

  PortableScoreDocument buildPortableDocument() {
    return _library.buildPortableDocument();
  }

  Future<void> deleteSavedScore(String id) async {
    await _library.deleteSavedScore(id);
  }

  void setDuration(NoteDuration duration) {
    _editor.setDuration(duration);
  }

  void handleRestAction() {
    _editor.handleRestAction();
  }

  void toggleDottedMode() {
    _editor.toggleDottedMode();
  }

  void toggleSlurMode() {
    _editor.toggleSlurMode();
  }

  void toggleTripletMode() {
    _editor.toggleTripletMode();
  }

  int resolveInputMidi(int rawMidi) {
    return _editor.resolveInputMidi(rawMidi);
  }

  bool canTapPianoKey(int midi) {
    return _editor.canTapPianoKey(midi);
  }

  void handlePianoTap(int midi) {
    _editor.handlePianoTap(midi);
  }

  void toggleKeyboardInputMode() {
    _editor.toggleKeyboardInputMode();
  }

  void shiftKeyboardMapping(int direction) {
    _editor.shiftKeyboardMapping(direction);
  }

  void handleEditorShortcut(EditorShortcutIntent shortcut) {
    _editor.handleEditorShortcut(shortcut);
  }

  void insertPitchedNote(int midi) {
    _editor.insertPitchedNote(midi);
  }

  void selectNote(int? index) {
    _editor.selectNote(index);
  }

  void selectTimeSig() {
    _editor.selectTimeSig();
  }

  void selectKeySig() {
    _editor.selectKeySig();
  }

  void selectClef() {
    _editor.selectClef();
  }

  void moveSelectionLeft() {
    _editor.moveSelectionLeft();
  }

  void moveSelectionRight() {
    _editor.moveSelectionRight();
  }

  void adjustSelection(int direction) {
    _editor.adjustSelection(direction);
  }

  void deleteSelected() {
    _editor.deleteSelected();
  }

  void changeSelectedPitch(int midi) {
    _editor.changeSelectedPitch(midi);
  }

  void changeSelectedDuration(NoteDuration duration) {
    _editor.changeSelectedDuration(duration);
  }

  void toggleSelectedDotted() {
    _editor.toggleSelectedDotted();
  }

  void moveCursor(int index) {
    _editor.moveCursor(index);
  }

  Future<void> play() async {
    await _playback.play();
  }

  void stop() {
    _playback.stop();
  }

  void setTempo(double bpm) {
    _editor.setTempo(bpm);
  }

  void setClef(Clef clef) {
    _editor.setClef(clef);
  }

  void cycleClef(int direction) {
    _editor.cycleClef(direction);
  }

  void setTimeSignature(int beats, int unit) {
    _editor.setTimeSignature(beats, unit);
  }

  void cycleTimeSignature(int direction) {
    _editor.cycleTimeSignature(direction);
  }

  void setKeySignature(KeySignature key) {
    _editor.setKeySignature(key);
  }

  void shiftKeySignature(int direction) {
    _editor.shiftKeySignature(direction);
  }

  Future<void> _runLibraryScoreReplacement(
    Future<void> Function() operation,
  ) async {
    if (_isDisposed) {
      return;
    }

    final workspaceBefore = _session.workspace;
    Object? failure;
    StackTrace? failureStack;
    _ownedControllerNotificationSuppressionDepth += 1;
    try {
      await operation();
    } catch (error, stackTrace) {
      failure = error;
      failureStack = stackTrace;
    } finally {
      _ownedControllerNotificationSuppressionDepth -= 1;
    }

    if (_isDisposed) {
      return;
    }

    if (!identical(workspaceBefore, _session.workspace)) {
      _resetEditorForScore();
      _observedWorkspace = _session.workspace;
    }
    notifyListeners();
    if (failure != null) {
      Error.throwWithStackTrace(failure, failureStack!);
    }
  }

  void _resetEditorForScore() {
    _ownedControllerNotificationSuppressionDepth += 1;
    try {
      _editor.resetForScore();
    } finally {
      _ownedControllerNotificationSuppressionDepth -= 1;
    }
  }

  void _notifyFromOwnedController() {
    if (_isDisposed || _ownedControllerNotificationSuppressionDepth > 0) {
      return;
    }
    if (!identical(_observedWorkspace, _session.workspace)) {
      _observedWorkspace = _session.workspace;
      _resetEditorForScore();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playback.removeListener(_notifyFromOwnedController);
    _editor.removeListener(_notifyFromOwnedController);
    _library.removeListener(_notifyFromOwnedController);
    if (_ownsControllers) {
      _library.dispose();
      _editor.dispose();
      _playback.dispose();
      _session.dispose();
    }
    super.dispose();
  }
}
