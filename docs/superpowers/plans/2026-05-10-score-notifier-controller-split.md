# Score Notifier Controller Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `ScoreNotifier` as a widget-facing API with `EditableScoreSession`, `EditorController`, `PlaybackController`, and `ScoreLibraryController`.

**Architecture:** `EditableScoreSession` owns the mutable `Score` and loaded `WorkspaceSession`. The three controllers expose separate editor, playback, and library APIs to widgets, startup coordination, and tests. The migration is complete only when `lib/state/score_notifier.dart` is deleted and no widget, screen, router, or test imports it.

**Tech Stack:** Flutter, Provider, ChangeNotifier, existing `WorkspaceRepository`, existing `AudioService`, Flutter widget/unit tests.

---

## File Structure

- Create `lib/state/editable_score_session.dart`: owns current score, workspace metadata, score replacement, dirty-state calculation, and score-change notifications.
- Create `lib/state/playback_controller.dart`: owns compose audio status, playback index, play/stop, note preview, and `AudioService` lifecycle.
- Create `lib/state/editor_controller.dart`: owns selection, cursor, toolbar state, editing commands, keyboard mode, and metadata edits.
- Create `lib/state/score_library_controller.dart`: owns workspace load/save/delete/import/restore, draft persistence, portable document creation, initial-load flags, and library messages.
- Modify `lib/workspace/workspace_startup_controller.dart`: accept the new controllers/session instead of `ScoreNotifier`.
- Modify `lib/app/tap_score_router.dart`: create one session and the three controllers per workspace page.
- Modify `lib/screens/workspace_screen.dart`: read the new controllers and session instead of `ScoreNotifier`.
- Modify `lib/widgets/score_view_widget.dart`: render from `EditableScoreSession`, handle editor events through `EditorController`, and playback highlighting through `PlaybackController`.
- Modify `lib/widgets/duration_selector.dart`, `lib/widgets/piano_keyboard.dart`, `lib/widgets/playback_controls.dart`, `lib/widgets/signature_pickers.dart`: replace `ScoreNotifier` imports and provider reads with the narrow controller/session dependencies.
- Modify tests under `test/state`, `test/widgets`, `test/app`, and `test/widget_test.dart`: replace `ScoreNotifier` harnesses with session/controller harnesses.
- Delete `lib/state/score_notifier.dart`.
- Add `test/tooling/no_score_notifier_usage_test.dart`: prevents reintroducing `ScoreNotifier`.

---

### Task 1: Introduce EditableScoreSession

**Files:**
- Create: `lib/state/editable_score_session.dart`
- Create: `test/state/editable_score_session_test.dart`

- [ ] **Step 1: Write failing session tests**

Create `test/state/editable_score_session_test.dart`:

```dart
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

  test('replaceWorkspace can replace the editor score and reset dirty state', () {
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
  });

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

  test('replaceScore resets selection-independent score fields from source', () {
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
  });
}
```

- [ ] **Step 2: Run failing tests**

Run:

```bash
flutter test test/state/editable_score_session_test.dart
```

Expected: fails because `EditableScoreSession` does not exist.

- [ ] **Step 3: Implement EditableScoreSession**

Create `lib/state/editable_score_session.dart`:

```dart
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
```

- [ ] **Step 4: Run session tests**

Run:

```bash
flutter test test/state/editable_score_session_test.dart
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add lib/state/editable_score_session.dart test/state/editable_score_session_test.dart
git commit -m "refactor: introduce editable score session"
```

---

### Task 2: Introduce PlaybackController

**Files:**
- Create: `lib/state/playback_controller.dart`
- Create: `test/state/playback_controller_test.dart`

- [ ] **Step 1: Write failing playback tests**

Create `test/state/playback_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/services/audio_service.dart';
import 'package:tap_score/state/editable_score_session.dart';
import 'package:tap_score/state/playback_controller.dart';

void main() {
  test('syncs audio initialization state into public audio status', () async {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(playback.dispose);
    addTearDown(session.dispose);

    expect(playback.audioStatus, AudioStatus.idle);

    await audioService.completePreload(success: true);

    expect(playback.audioStatus, AudioStatus.ready);
    expect(playback.audioStatusMessage, isNull);
  });

  test('previewNote forwards a short note to audio service', () {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(playback.dispose);
    addTearDown(session.dispose);

    playback.previewNote(64);

    expect(audioService.previewedMidis, [64]);
  });

  test('play reads the session score and updates playback state', () async {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    session.score.addNote(const Note(midi: 60, duration: NoteDuration.quarter));
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(playback.dispose);
    addTearDown(session.dispose);

    await playback.play();

    expect(audioService.playedScores.single.notes.single.midi, 60);
    expect(playback.isPlaying, isFalse);
    expect(playback.playbackIndex, -1);
  });

  test('stop resets state and stops the audio service', () {
    final audioService = _FakeAudioService();
    final session = EditableScoreSession();
    session.score.addNote(const Note(midi: 60));
    final playback = PlaybackController(
      session: session,
      audioService: audioService,
    );
    addTearDown(playback.dispose);
    addTearDown(session.dispose);

    playback.stop();

    expect(audioService.stopCalls, 1);
    expect(playback.isPlaying, isFalse);
    expect(playback.playbackIndex, -1);
  });
}

class _FakeAudioService extends AudioService {
  final List<int> previewedMidis = [];
  final List<Score> playedScores = [];
  int stopCalls = 0;

  Future<bool> completePreload({required bool success}) async {
    final result = await preload();
    return result && success;
  }

  @override
  Future<bool> preload({
    Duration webTimeout = const Duration(seconds: 12),
  }) async {
    onStateChanged?.call();
    return true;
  }

  @override
  void playNoteWithDuration(
    int midi, {
    Duration duration = const Duration(milliseconds: 400),
    int velocity = AudioService.defaultPlaybackVelocity,
  }) {
    previewedMidis.add(midi);
  }

  @override
  Future<void> playScore(
    Score score, {
    required void Function(int index) onNoteIndex,
    required void Function() onComplete,
  }) async {
    playedScores.add(score.copy());
    onNoteIndex(0);
    onComplete();
  }

  @override
  void stopPlayback() {
    stopCalls += 1;
  }

  @override
  void dispose() {}
}
```

- [ ] **Step 2: Run failing playback tests**

Run:

```bash
flutter test test/state/playback_controller_test.dart
```

Expected: fails because `PlaybackController` and `AudioStatus` do not exist.

- [ ] **Step 3: Implement PlaybackController**

Create `lib/state/playback_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../services/audio_service.dart';
import 'editable_score_session.dart';

enum AudioStatus { idle, preloading, ready, error }

class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required EditableScoreSession session,
    AudioService? audioService,
  }) : _session = session,
       _audioService = audioService ?? AudioService() {
    _audioService.onStateChanged = _syncAudioState;
    _syncAudioState(notify: false);
  }

  final EditableScoreSession _session;
  final AudioService _audioService;

  bool _isPlaying = false;
  int _playbackIndex = -1;
  AudioStatus _audioStatus = AudioStatus.idle;
  String? _audioStatusMessage;

  bool get isPlaying => _isPlaying;
  int get playbackIndex => _playbackIndex;
  AudioStatus get audioStatus => _audioStatus;
  bool get isInitialized => _audioStatus == AudioStatus.ready;
  String? get audioStatusMessage => _audioStatusMessage;
  bool get audioStatusIsError => _audioStatus == AudioStatus.error;

  void previewNote(
    int midi, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    _audioService.playNoteWithDuration(midi, duration: duration);
  }

  Future<void> preload() {
    return _audioService.preload().then((_) => _syncAudioState());
  }

  Future<void> play() async {
    if (_session.score.notes.isEmpty || _isPlaying) return;

    _isPlaying = true;
    _playbackIndex = 0;
    notifyListeners();

    await _audioService.playScore(
      _session.score,
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

  void stop() {
    _audioService.stopPlayback();
    _isPlaying = false;
    _playbackIndex = -1;
    notifyListeners();
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
        _audioStatusMessage = 'Preparing piano audio...';
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

  @override
  void dispose() {
    stop();
    _audioService.onStateChanged = null;
    _audioService.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run playback tests**

Run:

```bash
flutter test test/state/playback_controller_test.dart
```

Expected: pass. If the audio status test still reports `idle`, adjust `_FakeAudioService` to expose state transitions in the same way existing fake audio services do in `test/state/score_notifier_test.dart`.

- [ ] **Step 5: Commit**

```bash
git add lib/state/playback_controller.dart test/state/playback_controller_test.dart
git commit -m "refactor: introduce playback controller"
```

---

### Task 3: Introduce EditorController

**Files:**
- Create: `lib/state/editor_controller.dart`
- Modify: `test/state/score_notifier_test.dart`
- Rename through git: `test/state/score_notifier_test.dart` to `test/state/editor_controller_test.dart`

- [ ] **Step 1: Rename editor tests and update imports**

Run:

```bash
git mv test/state/score_notifier_test.dart test/state/editor_controller_test.dart
```

In `test/state/editor_controller_test.dart`, replace the imports:

```dart
import 'package:tap_score/state/editable_score_session.dart';
import 'package:tap_score/state/editor_controller.dart';
import 'package:tap_score/state/playback_controller.dart';
```

Remove:

```dart
import 'package:tap_score/state/score_notifier.dart';
```

Add this helper near the top of the file:

```dart
_EditorHarness buildEditorHarness() {
  final session = EditableScoreSession();
  final playback = _PreviewPlaybackController(session: session);
  final editor = EditorController(session: session, notePreview: playback);
  return _EditorHarness(
    session: session,
    playback: playback,
    editor: editor,
  );
}

class _EditorHarness {
  const _EditorHarness({
    required this.session,
    required this.playback,
    required this.editor,
  });

  final EditableScoreSession session;
  final _PreviewPlaybackController playback;
  final EditorController editor;

  void dispose() {
    editor.dispose();
    playback.dispose();
    session.dispose();
  }
}

class _PreviewPlaybackController extends PlaybackController {
  _PreviewPlaybackController({required super.session});

  final List<int> previewedMidis = [];

  @override
  void previewNote(
    int midi, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    previewedMidis.add(midi);
  }
}
```

Then replace simple constructions:

```dart
final notifier = ScoreNotifier();
```

with:

```dart
final harness = buildEditorHarness();
addTearDown(harness.dispose);
final notifier = harness.editor;
final score = harness.session.score;
```

For assertions that currently read `notifier.score`, replace with `score` or `harness.session.score`.

- [ ] **Step 2: Add fail-fast selection test**

Append this test to `test/state/editor_controller_test.dart`:

```dart
test('selectNote throws for invalid note indexes', () {
  final harness = buildEditorHarness();
  addTearDown(harness.dispose);

  expect(
    () => harness.editor.selectNote(0),
    throwsA(isA<RangeError>()),
  );
});
```

- [ ] **Step 3: Run renamed tests to verify failures**

Run:

```bash
flutter test test/state/editor_controller_test.dart
```

Expected: fails because `EditorController` does not exist.

- [ ] **Step 4: Implement EditorController by moving editor-owned code**

Create `lib/state/editor_controller.dart`.

Move `SelectionKind` from `lib/state/score_notifier.dart` into this file:

```dart
enum SelectionKind { clef, keySig, timeSig, note }
```

Create the class header:

```dart
import 'package:flutter/foundation.dart';

import '../input/editor_shortcuts.dart';
import '../models/enums.dart';
import '../models/key_signature.dart';
import '../models/note.dart';
import '../models/score.dart';
import 'editable_score_session.dart';
import 'playback_controller.dart';

class EditorController extends ChangeNotifier {
  static const double _epsilon = 0.001;

  EditorController({
    required EditableScoreSession session,
    required PlaybackController notePreview,
  }) : _session = session,
       _notePreview = notePreview {
    _syncNextTripletGroupId();
  }

  final EditableScoreSession _session;
  final PlaybackController _notePreview;

  Score get score => _session.score;
}
```

Move these members unchanged from `ScoreNotifier` into `EditorController`, replacing `_notifyScoreChanged()` calls with `_session.markScoreChanged()` and replacing `_audioService.playNoteWithDuration(...)` with `_notePreview.previewNote(...)`:

- selection/editor fields and getters from old lines 63-115
- toolbar derived getters from old lines 164-231
- `_measureDuration`, triplet derived helpers from old lines 402-430
- editor command methods from old lines 575-1421
- `_syncNextTripletGroupId()` from old lines 1468-1477

Add this public reset method at the end of `EditorController`:

```dart
void resetForScore() {
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
  notifyListeners();
}
```

Change invalid index behavior in `selectNote` from a silent return:

```dart
if (index != null && (index < 0 || index >= score.notes.length)) return;
```

to:

```dart
if (index != null && (index < 0 || index >= score.notes.length)) {
  throw RangeError.index(index, score.notes, 'index');
}
```

Keep UI-disabled command guards such as `if (!durationButtonsEnabled) return;` unchanged.

- [ ] **Step 5: Run editor tests**

Run:

```bash
flutter test test/state/editor_controller_test.dart
```

Expected: pass after replacing all `notifier.score` references with `harness.session.score`.

- [ ] **Step 6: Commit**

```bash
git add lib/state/editor_controller.dart test/state/editor_controller_test.dart
git commit -m "refactor: introduce editor controller"
```

---

### Task 4: Introduce ScoreLibraryController

**Files:**
- Create: `lib/state/score_library_controller.dart`
- Modify and rename: `test/state/score_notifier_library_test.dart` to `test/state/score_library_controller_test.dart`

- [ ] **Step 1: Rename library tests and update harness**

Run:

```bash
git mv test/state/score_notifier_library_test.dart test/state/score_library_controller_test.dart
```

In `test/state/score_library_controller_test.dart`, replace the `ScoreNotifier` import with:

```dart
import 'package:tap_score/state/editable_score_session.dart';
import 'package:tap_score/state/playback_controller.dart';
import 'package:tap_score/state/score_library_controller.dart';
import 'package:tap_score/workspace/workspace_repository.dart';
```

Add this helper near the top:

```dart
_LibraryHarness buildLibraryHarness({
  ScoreLibraryRepository? scoreLibraryRepository,
  PresetScoreRepository? presetScoreRepository,
  AudioService? audioService,
}) {
  final session = EditableScoreSession();
  final playback = PlaybackController(
    session: session,
    audioService: audioService ?? _FakeAudioService(),
  );
  final workspaceRepository = DefaultWorkspaceRepository(
    scoreLibraryRepository:
        scoreLibraryRepository ?? _MemoryScoreLibraryRepository(),
    presetScoreRepository:
        presetScoreRepository ?? _MemoryPresetScoreRepository(),
  );
  final library = ScoreLibraryController(
    session: session,
    playback: playback,
    workspaceRepository: workspaceRepository,
  );
  return _LibraryHarness(
    session: session,
    playback: playback,
    library: library,
  );
}

class _LibraryHarness {
  const _LibraryHarness({
    required this.session,
    required this.playback,
    required this.library,
  });

  final EditableScoreSession session;
  final PlaybackController playback;
  final ScoreLibraryController library;

  void dispose() {
    library.dispose();
    playback.dispose();
    session.dispose();
  }
}
```

Replace old constructions with the harness. Example:

```dart
final notifier = ScoreNotifier(
  audioService: _FakeAudioService(),
  scoreLibraryRepository: repository,
  presetScoreRepository: _MemoryPresetScoreRepository(),
);
addTearDown(notifier.dispose);
```

becomes:

```dart
final harness = buildLibraryHarness(
  scoreLibraryRepository: repository,
  presetScoreRepository: _MemoryPresetScoreRepository(),
);
addTearDown(harness.dispose);
final library = harness.library;
final session = harness.session;
```

Then replace:

- `notifier.loadInitialWorkspace(...)` with `library.loadInitialWorkspace(...)`
- `notifier.saveCurrentScore(...)` with `library.saveCurrentScore(...)`
- `notifier.loadSavedScore(...)` with `library.loadSavedScore(...)`
- `notifier.loadPresetScore(...)` with `library.loadPresetScore(...)`
- `notifier.importScoreDocument(...)` with `library.importScoreDocument(...)`
- `notifier.deleteSavedScore(...)` with `library.deleteSavedScore(...)`
- `notifier.restoreDraft()` with `library.restoreDraft()`
- `notifier.score` with `session.score`
- document/catalog/message getters with `library` when the data is library-owned and with `session` when the data is score/workspace-owned.

- [ ] **Step 2: Run renamed tests to verify failures**

Run:

```bash
flutter test test/state/score_library_controller_test.dart
```

Expected: fails because `ScoreLibraryController` does not exist.

- [ ] **Step 3: Implement ScoreLibraryController**

Create `lib/state/score_library_controller.dart`:

```dart
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

  bool get initialWorkspaceLoadComplete => _initialWorkspaceLoadComplete;
  bool get initialWorkspaceLoadSucceeded => _initialWorkspaceLoadSucceeded;
  String? get libraryMessage => _libraryMessage;
  bool get libraryMessageIsError => _libraryMessageIsError;

  List<SavedScoreEntry> get savedScores => _session.savedScores;
  List<PresetScoreEntry> get presetScores => _session.presetScores;
  String? get activeScoreId => _session.activeScoreId;
  String? get activePresetId => _session.activePresetId;
  SavedScoreEntry? get activeSavedScore => _session.activeSavedScore;
  PresetScoreEntry? get activePresetScore => _session.activePresetScore;
  String get currentScoreLabel => _session.currentScoreLabel;
  bool get hasUnsavedChanges => _session.hasUnsavedChanges;

  WorkspaceSession get _requiredWorkspace => _session.workspace;
}
```

Move these methods from `ScoreNotifier` into `ScoreLibraryController`, replacing direct score access with `_session.score`, workspace replacement with `_session.replaceWorkspace(...)`, and playback stop calls with `_playback.stop()`:

- `loadInitialWorkspace` old lines 252-314
- `_applyWorkspaceLoadResult` old lines 324-335
- `_persistInitializedWorkspace` old lines 348-372
- `clearLibraryMessage` old lines 432-439
- `showLibraryMessage` old lines 441-444
- `restoreDraft` old lines 446-460
- `saveCurrentScore` old lines 462-486
- `loadSavedScore` old lines 488-507
- `loadPresetScore` old lines 509-528
- `importScoreDocument` old lines 530-544
- `buildPortableDocument` old lines 546-552
- `deleteSavedScore` old lines 554-573
- `_scheduleDraftSave` old lines 1429-1444
- `_setLibraryMessage` old lines 1487-1496

When applying a workspace with `replaceScore: true`, also call the editor reset later from startup and load flows. Do not make `ScoreLibraryController` depend on `EditorController` in this task.

Add this dispose method:

```dart
@override
void dispose() {
  _session.removeScoreChangedListener(_scheduleDraftSave);
  _libraryMessageTimer?.cancel();
  _draftSaveTimer?.cancel();
  super.dispose();
}
```

- [ ] **Step 4: Run library tests**

Run:

```bash
flutter test test/state/score_library_controller_test.dart
```

Expected: pass after all old `notifier` references have been routed to `library` or `session`.

- [ ] **Step 5: Commit**

```bash
git add lib/state/score_library_controller.dart test/state/score_library_controller_test.dart
git commit -m "refactor: introduce score library controller"
```

---

### Task 5: Wire Controllers Into Startup And Router

**Files:**
- Modify: `lib/workspace/workspace_startup_controller.dart`
- Modify: `lib/app/tap_score_router.dart`
- Modify: `test/workspace/workspace_repository_test.dart`
- Modify: startup-related sections of `test/widget_test.dart`

- [ ] **Step 1: Add failing startup wiring expectations**

In `test/widget_test.dart`, update one workspace startup test to retrieve the new providers:

```dart
final session = Provider.of<EditableScoreSession>(context, listen: false);
final editor = Provider.of<EditorController>(context, listen: false);
final playback = Provider.of<PlaybackController>(context, listen: false);
final library = Provider.of<ScoreLibraryController>(context, listen: false);
expect(session.score.notes, isEmpty);
expect(editor.cursorIndex, 0);
expect(playback.isPlaying, isFalse);
expect(library.initialWorkspaceLoadComplete, isTrue);
```

Add imports:

```dart
import 'package:tap_score/state/editable_score_session.dart';
import 'package:tap_score/state/editor_controller.dart';
import 'package:tap_score/state/playback_controller.dart';
import 'package:tap_score/state/score_library_controller.dart';
```

- [ ] **Step 2: Run the targeted widget test**

Run the specific test name you changed:

```bash
flutter test test/widget_test.dart --plain-name "workspace"
```

Expected: fails until providers and startup use the new controllers.

- [ ] **Step 3: Update WorkspaceStartupController constructor and fields**

In `lib/workspace/workspace_startup_controller.dart`, replace:

```dart
required ScoreNotifier scoreNotifier,
```

with:

```dart
required EditableScoreSession session,
required EditorController editorController,
required PlaybackController playbackController,
required ScoreLibraryController scoreLibraryController,
```

Replace the field:

```dart
final ScoreNotifier _scoreNotifier;
```

with:

```dart
final EditableScoreSession _session;
final EditorController _editorController;
final PlaybackController _playbackController;
final ScoreLibraryController _scoreLibraryController;
```

Replace method calls:

- `_scoreNotifier.loadInitialWorkspace(...)` -> `_scoreLibraryController.loadInitialWorkspace(...)`
- `_scoreNotifier.initialWorkspaceLoadSucceeded` -> `_scoreLibraryController.initialWorkspaceLoadSucceeded`
- `_scoreNotifier.libraryMessage` -> `_scoreLibraryController.libraryMessage`
- `_scoreNotifier.stop()` -> `_playbackController.stop()`
- `_scoreNotifier.score` -> `_session.score`
- `_scoreNotifier.referenceBpm` -> `_session.referenceBpm`
- `_scoreNotifier.hasUnsavedChanges` -> `_session.hasUnsavedChanges`
- `_scoreNotifier.activePresetId` -> `_session.activePresetId`

After a successful load or mode switch that replaces the score, call:

```dart
_editorController.resetForScore();
```

- [ ] **Step 4: Update router provider setup**

In `lib/app/tap_score_router.dart`, replace the workspace page provider:

```dart
child: ChangeNotifierProvider(
  create: (_) =>
      ScoreNotifier(workspaceRepository: _workspaceRepository),
  child: WorkspaceScreen(
```

with:

```dart
child: _WorkspaceControllerScope(
  workspaceRepository: _workspaceRepository,
  child: WorkspaceScreen(
```

Add this private widget at the end of the file:

```dart
class _WorkspaceControllerScope extends StatefulWidget {
  const _WorkspaceControllerScope({
    required this.workspaceRepository,
    required this.child,
  });

  final WorkspaceRepository workspaceRepository;
  final Widget child;

  @override
  State<_WorkspaceControllerScope> createState() =>
      _WorkspaceControllerScopeState();
}

class _WorkspaceControllerScopeState extends State<_WorkspaceControllerScope> {
  late final EditableScoreSession _session = EditableScoreSession();
  late final PlaybackController _playbackController = PlaybackController(
    session: _session,
  );
  late final EditorController _editorController = EditorController(
    session: _session,
    notePreview: _playbackController,
  );
  late final ScoreLibraryController _libraryController =
      ScoreLibraryController(
        session: _session,
        playback: _playbackController,
        workspaceRepository: widget.workspaceRepository,
      );

  @override
  void dispose() {
    _libraryController.dispose();
    _editorController.dispose();
    _playbackController.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EditableScoreSession>.value(value: _session),
        ChangeNotifierProvider<PlaybackController>.value(
          value: _playbackController,
        ),
        ChangeNotifierProvider<EditorController>.value(
          value: _editorController,
        ),
        ChangeNotifierProvider<ScoreLibraryController>.value(
          value: _libraryController,
        ),
      ],
      child: widget.child,
    );
  }
}
```

Add imports for the four new state files and remove the `ScoreNotifier` import.

- [ ] **Step 5: Run startup and router tests**

Run:

```bash
flutter test test/workspace/workspace_repository_test.dart test/widget_test.dart --plain-name "workspace"
```

Expected: pass after updating remaining provider reads in startup paths.

- [ ] **Step 6: Commit**

```bash
git add lib/workspace/workspace_startup_controller.dart lib/app/tap_score_router.dart test/widget_test.dart
git commit -m "refactor: wire workspace controllers"
```

---

### Task 6: Migrate WorkspaceScreen

**Files:**
- Modify: `lib/screens/workspace_screen.dart`
- Modify: relevant workspace tests in `test/widget_test.dart`

- [ ] **Step 1: Update imports and startup construction**

In `lib/screens/workspace_screen.dart`, remove:

```dart
import '../state/score_notifier.dart';
```

Add:

```dart
import '../state/editable_score_session.dart';
import '../state/editor_controller.dart';
import '../state/playback_controller.dart';
import '../state/score_library_controller.dart';
```

Update startup construction:

```dart
_startupController = WorkspaceStartupController(
  session: context.read<EditableScoreSession>(),
  editorController: context.read<EditorController>(),
  playbackController: context.read<PlaybackController>(),
  scoreLibraryController: context.read<ScoreLibraryController>(),
  launchConfig: widget.launchConfig,
  requestFocus: _focusNode.requestFocus,
  onRouteSync: widget.onRouteSync,
  rhythmTestAudioService: widget.rhythmTestAudioService,
);
```

- [ ] **Step 2: Replace screen-level reads**

Use these replacements:

- save dialog reads `ScoreLibraryController`
- rhythm tempo change mutates `EditorController.setTempo`
- export builds document from `ScoreLibraryController.buildPortableDocument`
- export success/error messages call `ScoreLibraryController.showLibraryMessage`
- key handling uses `PlaybackController` for play/stop, `EditorController` for movement/edit shortcuts, and `EditableScoreSession.score` for clef/notes data
- top bar `hasUnsavedChanges` reads `EditableScoreSession`
- compose body receives `EditableScoreSession`, `EditorController`, and `PlaybackController`
- rhythm-test body reads `EditableScoreSession.score` and `ScoreLibraryController.libraryMessage`

Update `_SaveScoreDialog` constructor from:

```dart
const _SaveScoreDialog({required this.notifier});
final ScoreNotifier notifier;
```

to:

```dart
const _SaveScoreDialog({required this.libraryController});
final ScoreLibraryController libraryController;
```

Inside the dialog, replace `widget.notifier.activeSavedScore` and `widget.notifier.saveCurrentScore` with `widget.libraryController.activeSavedScore` and `widget.libraryController.saveCurrentScore`.

- [ ] **Step 3: Update compose toolbar signatures**

Change helper signatures:

```dart
Widget _buildWorkspaceBody(
  EditableScoreSession session,
  EditorController editor,
  PlaybackController playback,
  ScoreLibraryController library,
  WorkspaceLayoutProfile layoutProfile,
  WorkspaceStartupState startupState,
)
```

Use the same dependency split for `_buildComposeBody`, `_buildRhythmTestBody`, `_ComposeDock`, and `_ComposeToolbarLayout`.

- [ ] **Step 4: Run workspace screen tests**

Run:

```bash
flutter test test/widget_test.dart --plain-name "workspace"
```

Expected: pass after all `ScoreNotifier` references are removed from `WorkspaceScreen`.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/workspace_screen.dart test/widget_test.dart
git commit -m "refactor: migrate workspace screen controllers"
```

---

### Task 7: Migrate Score And Input Widgets

**Files:**
- Modify: `lib/widgets/score_view_widget.dart`
- Modify: `lib/widgets/duration_selector.dart`
- Modify: `lib/widgets/piano_keyboard.dart`
- Modify: `lib/widgets/playback_controls.dart`
- Modify: `lib/widgets/signature_pickers.dart`
- Modify: `test/widgets/score_view_widget_test.dart`
- Modify: `test/widgets/rhythm_test_workspace_test.dart`

- [ ] **Step 1: Update signature pickers**

In `lib/widgets/signature_pickers.dart`, replace `ScoreNotifier` with `EditableScoreSession` and `EditorController`:

```dart
void showClefPicker(
  BuildContext context, {
  required EditableScoreSession session,
  required EditorController editor,
})
```

Use `session.score.clef` to determine the current value and `editor.setClef(clef)` to mutate. Apply the same pattern for `showTimeSigPicker` and `showKeySigPicker`.

- [ ] **Step 2: Update score view widget dependencies**

In `lib/widgets/score_view_widget.dart`:

- Replace `_notifier` with `_session`, `_editor`, and `_playback`.
- Listen to both `_session` and `_editor` for static render changes.
- Use `context.read<EditableScoreSession>()`, `context.read<EditorController>()`, and `context.read<PlaybackController>()`.
- Use `widget.playbackIndex ?? playback.playbackIndex` for playback commands.
- Route renderer taps and keys to `EditorController`.

Rename `_handleScoreNotifierChanged` to:

```dart
void _handleScoreOrEditorChanged() {
  _flushRendererCommands(staticChanged: true);
}
```

- [ ] **Step 3: Update duration selector**

In `lib/widgets/duration_selector.dart`, replace:

```dart
return Consumer<ScoreNotifier>(
  builder: (context, notifier, child) {
```

with:

```dart
return Consumer<EditorController>(
  builder: (context, editor, child) {
```

Then replace all `notifier.` toolbar and command references with `editor.`.

- [ ] **Step 4: Update piano keyboard**

In `lib/widgets/piano_keyboard.dart`, use:

```dart
final session = context.watch<EditableScoreSession>();
final editor = context.watch<EditorController>();
```

Replace:

- `notifier.keyboardInputMode` -> `editor.keyboardInputMode`
- `notifier.keyboardOctaveShift` -> `editor.keyboardOctaveShift`
- `notifier.score.clef` -> `session.score.clef`
- `notifier.canTapPianoKey(midi)` -> `editor.canTapPianoKey(midi)`
- `notifier.handlePianoTap(midi)` -> `editor.handlePianoTap(midi)`
- `notifier.resolveInputMidi(midi)` -> `editor.resolveInputMidi(midi)`

- [ ] **Step 5: Update playback controls**

In `lib/widgets/playback_controls.dart`, update tempo, time signature, and key signature controls:

- `ComposeTempoChip` reads `EditableScoreSession.score.bpm`
- tempo slider calls `EditorController.setTempo`
- time/key chips call picker functions with `session` and `editor`

- [ ] **Step 6: Update widget harnesses**

In `test/widgets/score_view_widget_test.dart`, replace `_buildScoreViewHarness` with:

```dart
Widget _buildScoreViewHarness({
  required Duration rendererCommandTimeout,
}) {
  final session = EditableScoreSession();
  final playback = PlaybackController(
    session: session,
    audioService: AudioService(testMode: true),
  );
  final editor = EditorController(session: session, notePreview: playback);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EditableScoreSession>.value(value: session),
      ChangeNotifierProvider<PlaybackController>.value(value: playback),
      ChangeNotifierProvider<EditorController>.value(value: editor),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ScoreViewWidget(rendererCommandTimeout: rendererCommandTimeout),
      ),
    ),
  );
}
```

Remove the `notifier:` argument at call sites.

- [ ] **Step 7: Run widget tests**

Run:

```bash
flutter test test/widgets/score_view_widget_test.dart test/widgets/rhythm_test_workspace_test.dart
```

Expected: pass after all widget imports are migrated.

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/score_view_widget.dart lib/widgets/duration_selector.dart lib/widgets/piano_keyboard.dart lib/widgets/playback_controls.dart lib/widgets/signature_pickers.dart test/widgets/score_view_widget_test.dart test/widgets/rhythm_test_workspace_test.dart
git commit -m "refactor: migrate score widgets to controllers"
```

---

### Task 8: Migrate Remaining App And Broad Widget Tests

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `test/app/navigation_flow_test.dart`
- Modify: any test listed by `rg "ScoreNotifier" test`

- [ ] **Step 1: Replace broad test harness constructors**

In `test/widget_test.dart`, replace helpers that return or accept `ScoreNotifier` with harness objects:

```dart
class WorkspaceControllerHarness {
  WorkspaceControllerHarness({
    WorkspaceRepository? workspaceRepository,
    AudioService? audioService,
  }) {
    session = EditableScoreSession();
    playback = PlaybackController(
      session: session,
      audioService: audioService ?? AudioService(testMode: true),
    );
    editor = EditorController(session: session, notePreview: playback);
    library = ScoreLibraryController(
      session: session,
      playback: playback,
      workspaceRepository:
          workspaceRepository ??
          DefaultWorkspaceRepository(
            scoreLibraryRepository: _WidgetMemoryScoreLibraryRepository(),
            presetScoreRepository: _WidgetMemoryPresetScoreRepository(),
          ),
    );
  }

  late final EditableScoreSession session;
  late final PlaybackController playback;
  late final EditorController editor;
  late final ScoreLibraryController library;

  List<ChangeNotifierProvider<ChangeNotifier>> get providers => [
    ChangeNotifierProvider<EditableScoreSession>.value(value: session),
    ChangeNotifierProvider<PlaybackController>.value(value: playback),
    ChangeNotifierProvider<EditorController>.value(value: editor),
    ChangeNotifierProvider<ScoreLibraryController>.value(value: library),
  ];

  void dispose() {
    library.dispose();
    editor.dispose();
    playback.dispose();
    session.dispose();
  }
}
```

If Dart rejects the typed `providers` getter because of generic invariance, replace it with this method:

```dart
Widget wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<EditableScoreSession>.value(value: session),
      ChangeNotifierProvider<PlaybackController>.value(value: playback),
      ChangeNotifierProvider<EditorController>.value(value: editor),
      ChangeNotifierProvider<ScoreLibraryController>.value(value: library),
    ],
    child: child,
  );
}
```

- [ ] **Step 2: Update navigation flow tests**

In `test/app/navigation_flow_test.dart`, replace provider reads:

```dart
final notifier = Provider.of<ScoreNotifier>(context, listen: false);
```

with:

```dart
final session = Provider.of<EditableScoreSession>(context, listen: false);
final editor = Provider.of<EditorController>(context, listen: false);
final library = Provider.of<ScoreLibraryController>(context, listen: false);
```

Route assertions about score contents through `session.score`, editor actions through `editor`, and save/load/library assertions through `library`.

- [ ] **Step 3: Run broad tests**

Run:

```bash
flutter test test/widget_test.dart test/app/navigation_flow_test.dart
```

Expected: pass after all broad harnesses use the new providers.

- [ ] **Step 4: Commit**

```bash
git add test/widget_test.dart test/app/navigation_flow_test.dart
git commit -m "test: migrate workspace harnesses to controllers"
```

---

### Task 9: Delete ScoreNotifier And Add Usage Guard

**Files:**
- Delete: `lib/state/score_notifier.dart`
- Create: `test/tooling/no_score_notifier_usage_test.dart`
- Modify: any remaining file reported by `rg "score_notifier|ScoreNotifier" lib test`

- [ ] **Step 1: Add failing guard test**

Create `test/tooling/no_score_notifier_usage_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScoreNotifier is not used by app or tests', () {
    final roots = [
      Directory('lib'),
      Directory('test'),
    ];
    final offenders = <String>[];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.path == 'test/tooling/no_score_notifier_usage_test.dart') {
          continue;
        }
        final contents = entity.readAsStringSync();
        if (contents.contains('ScoreNotifier') ||
            contents.contains('score_notifier.dart')) {
          offenders.add(entity.path);
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 2: Run guard test and inspect offenders**

Run:

```bash
flutter test test/tooling/no_score_notifier_usage_test.dart
rg -n "score_notifier|ScoreNotifier" lib test
```

Expected: guard fails and `rg` lists remaining references.

- [ ] **Step 3: Remove remaining references**

For every `rg` hit:

- replace imports with the new controller/session imports
- replace provider reads with the narrow controller/session
- replace score data reads with `EditableScoreSession`
- replace editor commands with `EditorController`
- replace playback commands/status with `PlaybackController`
- replace library actions/messages with `ScoreLibraryController`

Then delete the old file:

```bash
git rm lib/state/score_notifier.dart
```

- [ ] **Step 4: Run guard and focused state tests**

Run:

```bash
flutter test test/tooling/no_score_notifier_usage_test.dart test/state/editable_score_session_test.dart test/state/editor_controller_test.dart test/state/playback_controller_test.dart test/state/score_library_controller_test.dart
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add test/tooling/no_score_notifier_usage_test.dart
git add lib test
git commit -m "refactor: remove score notifier"
```

---

### Task 10: Full Verification And Manual Chrome Smoke Test

**Files:**
- No planned source changes unless verification exposes a concrete defect.

- [ ] **Step 1: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: no analyzer errors.

- [ ] **Step 2: Run all automated tests**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Run web app for manual smoke testing**

Run:

```bash
flutter run -d chrome
```

Expected: app starts in Chrome.

Manual checks:

- open editor from home
- insert a note with the piano keyboard
- change duration, dotted mode, tie/slur mode, and triplet mode
- use arrow keys to move selection
- save a score
- export a score
- switch to rhythm test with a non-empty score
- return to editor and confirm playback still works

- [ ] **Step 4: Commit verification fixes if any**

If verification required code fixes:

```bash
git add lib test
git commit -m "fix: stabilize controller split migration"
```

If no fixes were needed, do not create an empty commit.

---

## Self-Review

Spec coverage:

- Shared score/workspace ownership is covered by Task 1.
- Playback/audio ownership is covered by Task 2.
- Editor ownership is covered by Task 3.
- Library/draft persistence ownership is covered by Task 4.
- Startup, router, screen, and widget migration are covered by Tasks 5-8.
- Removing `ScoreNotifier` from widget usage is enforced by Task 9.
- Verification targets from the spec are covered by Task 10.

Placeholder scan:

- The plan contains no placeholder markers or unspecified implementation slots.

Type consistency:

- Controller names are `EditableScoreSession`, `EditorController`, `PlaybackController`, and `ScoreLibraryController` throughout.
- `AudioStatus` is defined in `playback_controller.dart` and replaces the old enum from `score_notifier.dart`.
- `SelectionKind` is defined in `editor_controller.dart` and replaces the old enum from `score_notifier.dart`.
