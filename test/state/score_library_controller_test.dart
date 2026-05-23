import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/app/score_seed_config.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/portable_score_document.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';
import 'package:tap_score/services/audio_service.dart';
import 'package:tap_score/services/preset_score_repository.dart';
import 'package:tap_score/services/score_library_repository.dart';
import 'package:tap_score/state/editable_score_session.dart';
import 'package:tap_score/state/editor_controller.dart';
import 'package:tap_score/state/playback_controller.dart';
import 'package:tap_score/state/score_library_controller.dart';
import 'package:tap_score/workspace/workspace_repository.dart';

void main() {
  test(
    'loadInitialWorkspace restores the persisted draft and active score reference',
    () async {
      final repository = _MemoryScoreLibraryRepository(
        ScoreLibrarySnapshot(
          draft: Score(
            notes: const [Note(midi: 65, duration: NoteDuration.half)],
            bpm: 88,
          ),
          savedScores: [
            SavedScoreEntry(
              id: 'saved-1',
              name: 'Warmup',
              updatedAt: DateTime.utc(2026, 3, 22, 9, 0, 0),
              score: Score(
                notes: const [Note(midi: 65, duration: NoteDuration.half)],
                bpm: 88,
              ),
            ),
          ],
          activeScoreId: 'saved-1',
        ),
      );
      final harness = _LibraryHarness(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace();

      expect(harness.session.score.notes.single.midi, 65);
      expect(harness.session.score.bpm, 88);
      expect(harness.library.activeScoreId, 'saved-1');
      expect(harness.library.currentScoreLabel, 'Warmup');
      expect(harness.library.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'save as new stores multiple named scores and load restores each',
    () async {
      final repository = _MemoryScoreLibraryRepository();
      final harness = _LibraryHarness(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace();

      harness.insertPitchedNote(60);
      await harness.library.saveCurrentScore('First');

      harness.setTempo(144);
      await harness.library.saveCurrentScore('Second', createNew: true);

      expect(harness.library.savedScores, hasLength(2));
      final first = harness.library.savedScores.firstWhere(
        (entry) => entry.name == 'First',
      );
      final second = harness.library.savedScores.firstWhere(
        (entry) => entry.name == 'Second',
      );
      expect(first.id, isNot(second.id));

      await harness.library.loadSavedScore(first.id);
      expect(harness.session.score.bpm, 120);
      expect(harness.library.activeScoreId, first.id);
      expect(harness.library.currentScoreLabel, 'First');

      await harness.library.loadSavedScore(second.id);
      expect(harness.session.score.bpm, 144);
      expect(harness.library.activeScoreId, second.id);
      expect(harness.library.currentScoreLabel, 'Second');
    },
  );

  test('referenceBpm stays pinned to the baseline document tempo', () async {
    final repository = _MemoryScoreLibraryRepository(
      ScoreLibrarySnapshot(
        draft: Score(
          notes: const [Note(midi: 65, duration: NoteDuration.half)],
          bpm: 88,
        ),
        savedScores: [
          SavedScoreEntry(
            id: 'saved-1',
            name: 'Warmup',
            updatedAt: DateTime.utc(2026, 3, 22, 9, 0, 0),
            score: Score(
              notes: const [Note(midi: 65, duration: NoteDuration.half)],
              bpm: 88,
            ),
          ),
        ],
        activeScoreId: 'saved-1',
      ),
    );
    final harness = _LibraryHarness(
      scoreLibraryRepository: repository,
      presetScoreRepository: _MemoryPresetScoreRepository(),
    );
    addTearDown(harness.dispose);

    await harness.library.loadInitialWorkspace();

    expect(harness.session.referenceBpm, 88);

    harness.setTempo(120);

    expect(harness.session.score.bpm, 120);
    expect(harness.session.referenceBpm, 88);
  });

  test('score changes notify library listeners for unsaved state', () async {
    final harness = _LibraryHarness(
      scoreLibraryRepository: _MemoryScoreLibraryRepository(),
      presetScoreRepository: _MemoryPresetScoreRepository(),
    );
    addTearDown(harness.dispose);

    await harness.library.loadInitialWorkspace();

    var listenerCalls = 0;
    harness.library.addListener(() {
      listenerCalls += 1;
    });

    harness.insertPitchedNote(64);

    expect(listenerCalls, 1);
    expect(harness.library.hasUnsavedChanges, isTrue);
  });

  test('loadInitialWorkspace does not notify after dispose', () async {
    final repository = _ControlledLoadScoreLibraryRepository();
    final harness = _LibraryHarness(
      scoreLibraryRepository: repository,
      presetScoreRepository: _MemoryPresetScoreRepository(),
    );

    final load = harness.library.loadInitialWorkspace();
    await Future<void>.delayed(Duration.zero);

    harness.dispose();
    repository.completeLoad(
      ScoreLibrarySnapshot(
        draft: Score(notes: const [Note(midi: 60)]),
        savedScores: const [],
      ),
    );

    await load;
  });

  test(
    'delete clears the active saved reference when removing the current score',
    () async {
      final repository = _MemoryScoreLibraryRepository();
      final harness = _LibraryHarness(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace();

      harness.insertPitchedNote(72);
      await harness.library.saveCurrentScore('Solo');
      final savedId = harness.library.activeScoreId!;

      await harness.library.deleteSavedScore(savedId);

      expect(harness.library.savedScores, isEmpty);
      expect(harness.library.activeScoreId, isNull);
      expect(harness.library.currentScoreLabel, 'Draft');
      expect(harness.library.hasUnsavedChanges, isFalse);
    },
  );

  test('loadInitialWorkspace loads presets alongside saved scores', () async {
    final harness = _LibraryHarness(
      scoreLibraryRepository: _MemoryScoreLibraryRepository(),
      presetScoreRepository: _MemoryPresetScoreRepository(
        presets: [
          PresetScoreEntry(
            id: 'preset-1',
            name: 'Warmup',
            assetPath: 'assets/presets/warmup.json',
            score: Score(),
          ),
        ],
      ),
    );
    addTearDown(harness.dispose);

    await harness.library.loadInitialWorkspace();

    expect(harness.library.presetScores, hasLength(1));
    expect(harness.library.presetScores.single.name, 'Warmup');
  });

  test(
    'imported documents become draft without an active saved score',
    () async {
      final repository = _MemoryScoreLibraryRepository();
      final harness = _LibraryHarness(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace();
      await harness.library.importScoreDocument(
        PortableScoreDocument(
          version: PortableScoreDocument.currentVersion,
          name: 'Imported Etude',
          score: Score(
            notes: const [Note(midi: 72, duration: NoteDuration.whole)],
            bpm: 72,
          ),
        ),
      );

      expect(harness.library.activeScoreId, isNull);
      expect(harness.library.currentScoreLabel, 'Imported Etude');
      expect(harness.library.hasUnsavedChanges, isFalse);
      expect(repository.snapshot?.draft.bpm, 72);
    },
  );

  test('loading a preset does not add it to saved scores', () async {
    final harness = _LibraryHarness(
      scoreLibraryRepository: _MemoryScoreLibraryRepository(),
      presetScoreRepository: _MemoryPresetScoreRepository(
        presets: [
          PresetScoreEntry(
            id: 'preset-1',
            name: 'Triplet Study',
            assetPath: 'assets/presets/triplet_study.json',
            score: Score(
              notes: [Note(midi: 67, duration: NoteDuration.quarter)],
              bpm: 96,
            ),
          ),
        ],
      ),
    );
    addTearDown(harness.dispose);

    await harness.library.loadInitialWorkspace();
    await harness.library.loadPresetScore('preset-1');

    expect(harness.library.activeScoreId, isNull);
    expect(harness.library.activePresetId, 'preset-1');
    expect(harness.library.savedScores, isEmpty);
    expect(harness.library.currentScoreLabel, 'Triplet Study');
  });

  test('public score replacement paths reset attached editor state', () async {
    final scenarios =
        <
          ({
            String name,
            _LibraryHarness Function() buildHarness,
            Future<void> Function(_LibraryHarness harness) prepare,
            Future<void> Function(_LibraryHarness harness) replace,
          })
        >[
          (
            name: 'initial workspace load',
            buildHarness: () => _LibraryHarness(
              scoreLibraryRepository: _MemoryScoreLibraryRepository(
                ScoreLibrarySnapshot(
                  draft: Score(notes: const [Note(midi: 64)]),
                  savedScores: const [],
                ),
              ),
              presetScoreRepository: _MemoryPresetScoreRepository(),
            ),
            prepare: (_) async {},
            replace: (harness) => harness.library.loadInitialWorkspace(),
          ),
          (
            name: 'draft restore',
            buildHarness: () => _LibraryHarness(
              scoreLibraryRepository: _MemoryScoreLibraryRepository(
                ScoreLibrarySnapshot(
                  draft: Score(notes: const [Note(midi: 65)]),
                  savedScores: const [],
                ),
              ),
              presetScoreRepository: _MemoryPresetScoreRepository(),
            ),
            prepare: (harness) => harness.library.loadInitialWorkspace(),
            replace: (harness) => harness.library.restoreDraft(),
          ),
          (
            name: 'saved score load',
            buildHarness: () => _LibraryHarness(
              scoreLibraryRepository: _MemoryScoreLibraryRepository(
                ScoreLibrarySnapshot(
                  draft: Score(),
                  savedScores: [
                    SavedScoreEntry(
                      id: 'saved-1',
                      name: 'Saved Piece',
                      updatedAt: DateTime.utc(2026, 3, 23, 12),
                      score: Score(notes: const [Note(midi: 67)]),
                    ),
                  ],
                ),
              ),
              presetScoreRepository: _MemoryPresetScoreRepository(),
            ),
            prepare: (harness) => harness.library.loadInitialWorkspace(),
            replace: (harness) => harness.library.loadSavedScore('saved-1'),
          ),
          (
            name: 'preset score load',
            buildHarness: () => _LibraryHarness(
              scoreLibraryRepository: _MemoryScoreLibraryRepository(),
              presetScoreRepository: _MemoryPresetScoreRepository(
                presets: [
                  PresetScoreEntry(
                    id: 'preset-1',
                    name: 'Preset Piece',
                    assetPath: 'assets/presets/preset_piece.json',
                    score: Score(notes: const [Note(midi: 69)]),
                  ),
                ],
              ),
            ),
            prepare: (harness) => harness.library.loadInitialWorkspace(),
            replace: (harness) => harness.library.loadPresetScore('preset-1'),
          ),
          (
            name: 'document import',
            buildHarness: () => _LibraryHarness(
              scoreLibraryRepository: _MemoryScoreLibraryRepository(),
              presetScoreRepository: _MemoryPresetScoreRepository(),
            ),
            prepare: (harness) => harness.library.loadInitialWorkspace(),
            replace: (harness) => harness.library.importScoreDocument(
              PortableScoreDocument(
                version: PortableScoreDocument.currentVersion,
                name: 'Imported Piece',
                score: Score(notes: const [Note(midi: 71)]),
              ),
            ),
          ),
        ];

    for (final scenario in scenarios) {
      final harness = scenario.buildHarness();
      addTearDown(harness.dispose);

      await scenario.prepare(harness);
      _dirtyEditorForReplacement(harness);

      await scenario.replace(harness);

      _expectEditorResetAfterReplacement(harness, reason: scenario.name);
    }
  });

  test(
    'blank launch starts a new empty draft without preloading audio',
    () async {
      final repository = _MemoryScoreLibraryRepository(
        ScoreLibrarySnapshot(
          draft: Score(
            notes: const [Note(midi: 64, duration: NoteDuration.quarter)],
            bpm: 90,
          ),
          savedScores: [
            SavedScoreEntry(
              id: 'saved-1',
              name: 'Saved Piece',
              updatedAt: DateTime.utc(2026, 3, 23, 12),
              score: Score(
                notes: const [Note(midi: 60, duration: NoteDuration.half)],
              ),
            ),
          ],
        ),
      );
      final audioService = _FakeAudioService();
      final harness = _LibraryHarness(
        audioService: audioService,
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace(
        initialScoreConfig: const ScoreSeedConfig.blank(),
      );

      expect(harness.session.score.notes, isEmpty);
      expect(harness.library.activeScoreId, isNull);
      expect(harness.library.activePresetId, isNull);
      expect(harness.library.savedScores, hasLength(1));
      expect(harness.library.currentScoreLabel, 'Draft');
      expect(audioService.preloadCalls, 0);
      expect(repository.snapshot?.draft.notes, isEmpty);
    },
  );

  test(
    'blank launch still applies in memory when the initial draft write fails',
    () async {
      final repository = _FailingSaveScoreLibraryRepository(
        ScoreLibrarySnapshot(
          draft: Score(
            notes: const [Note(midi: 64, duration: NoteDuration.quarter)],
            bpm: 90,
          ),
          savedScores: const [],
        ),
      );
      final harness = _LibraryHarness(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace(
        initialScoreConfig: const ScoreSeedConfig.blank(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(harness.session.score.notes, isEmpty);
      expect(harness.library.currentScoreLabel, 'Draft');
      expect(
        harness.library.libraryMessage,
        'Failed to write the local score library.',
      );
      expect(harness.library.libraryMessageIsError, isTrue);
    },
  );

  test(
    'blank launch falls back to local state when preset loading fails',
    () async {
      final harness = _LibraryHarness(
        scoreLibraryRepository: _MemoryScoreLibraryRepository(
          ScoreLibrarySnapshot(
            draft: Score(
              notes: const [Note(midi: 65, duration: NoteDuration.half)],
              bpm: 88,
            ),
            savedScores: [
              SavedScoreEntry(
                id: 'saved-1',
                name: 'Warmup',
                updatedAt: DateTime.utc(2026, 3, 22, 9, 0, 0),
                score: Score(
                  notes: const [Note(midi: 65, duration: NoteDuration.half)],
                  bpm: 88,
                ),
              ),
            ],
            activeScoreId: 'saved-1',
          ),
        ),
        presetScoreRepository: _ThrowingPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace();

      expect(harness.session.score.notes.single.midi, 65);
      expect(harness.library.activeScoreId, 'saved-1');
      expect(harness.library.currentScoreLabel, 'Warmup');
      expect(
        harness.library.libraryMessage,
        'Failed to load preset score manifest.',
      );
      expect(harness.library.libraryMessageIsError, isTrue);
    },
  );

  test(
    'preset launch starts a draft initialized from the chosen preset',
    () async {
      final repository = _MemoryScoreLibraryRepository(
        ScoreLibrarySnapshot(
          draft: Score(
            notes: const [Note(midi: 64, duration: NoteDuration.quarter)],
          ),
          savedScores: [
            SavedScoreEntry(
              id: 'saved-1',
              name: 'Saved Piece',
              updatedAt: DateTime.utc(2026, 3, 23, 12),
              score: Score(
                notes: const [Note(midi: 60, duration: NoteDuration.half)],
              ),
            ),
          ],
        ),
      );
      final audioService = _FakeAudioService();
      final presetScore = Score(
        notes: const [Note(midi: 67, duration: NoteDuration.quarter)],
        bpm: 96,
      );
      final harness = _LibraryHarness(
        audioService: audioService,
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(
          presets: [
            PresetScoreEntry(
              id: 'preset-1',
              name: 'Triplet Study',
              assetPath: 'assets/presets/triplet_study.json',
              score: presetScore,
            ),
          ],
        ),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace(
        initialScoreConfig: const ScoreSeedConfig.preset('preset-1'),
      );

      expect(harness.session.score.notes, hasLength(1));
      expect(harness.session.score.notes.single.midi, 67);
      expect(harness.library.activeScoreId, isNull);
      expect(harness.library.activePresetId, 'preset-1');
      expect(harness.library.savedScores, hasLength(1));
      expect(harness.library.currentScoreLabel, 'Triplet Study');
      expect(audioService.preloadCalls, 0);
      expect(repository.snapshot?.draft.notes.single.midi, 67);
    },
  );

  test(
    'loadInitialWorkspace retries after an initial repository failure',
    () async {
      final repository = _SequencedScoreLibraryRepository([
        Future<ScoreLibrarySnapshot?>.error(
          const ScoreLibraryStorageException('First load failed.'),
        ),
        Future<ScoreLibrarySnapshot?>.value(
          ScoreLibrarySnapshot(
            draft: Score(
              notes: const [Note(midi: 69, duration: NoteDuration.quarter)],
            ),
            savedScores: const [],
          ),
        ),
      ]);
      final harness = _LibraryHarness(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      await harness.library.loadInitialWorkspace();

      expect(repository.loadCalls, 1);
      expect(harness.library.initialWorkspaceLoadComplete, isTrue);
      expect(harness.library.initialWorkspaceLoadSucceeded, isFalse);
      expect(harness.library.libraryMessage, 'First load failed.');
      expect(harness.library.libraryMessageIsError, isTrue);

      await harness.library.loadInitialWorkspace();

      expect(repository.loadCalls, 2);
      expect(harness.library.initialWorkspaceLoadComplete, isTrue);
      expect(harness.library.initialWorkspaceLoadSucceeded, isTrue);
      expect(harness.session.score.notes.single.midi, 69);
      expect(harness.library.libraryMessage, isNull);
      expect(harness.library.libraryMessageIsError, isFalse);
    },
  );

  test('loadInitialWorkspace cancels pending draft saves', () async {
    final repository = _CountingSaveScoreLibraryRepository();
    final harness = _LibraryHarness(
      scoreLibraryRepository: repository,
      presetScoreRepository: _MemoryPresetScoreRepository(),
    );
    addTearDown(harness.dispose);

    await harness.library.loadInitialWorkspace();

    harness.insertPitchedNote(60);
    await harness.library.loadInitialWorkspace();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(repository.saveCalls, 0);
  });

  test(
    'stale initial persist failure does not replace newer load message',
    () async {
      final repository = _ControlledSaveScoreLibraryRepository([
        () => Future<ScoreLibrarySnapshot?>.value(
          ScoreLibrarySnapshot(draft: Score(), savedScores: const []),
        ),
        () => Future<ScoreLibrarySnapshot?>.error(
          const ScoreLibraryStorageException('Second load failed.'),
        ),
      ]);
      final harness = _LibraryHarness(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(harness.dispose);

      final firstLoad = harness.library.loadInitialWorkspace(
        initialScoreConfig: const ScoreSeedConfig.blank(),
      );
      await repository.waitForPendingSave();

      await harness.library.loadInitialWorkspace();
      expect(harness.library.libraryMessage, 'Second load failed.');

      repository.pendingSave!.completeError(
        const ScoreLibraryStorageException('Stale write failed.'),
      );
      await Future<void>.delayed(Duration.zero);
      await firstLoad;

      expect(harness.library.libraryMessage, 'Second load failed.');
      expect(harness.library.libraryMessageIsError, isTrue);
    },
  );

  test(
    'newer initial persist cannot be overwritten by stale initial persist',
    () async {
      final repository = _QueuedSaveScoreLibraryRepository();
      final harness = _LibraryHarness(
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(
          presets: [
            PresetScoreEntry(
              id: 'preset-1',
              name: 'Triplet Study',
              assetPath: 'assets/presets/triplet_study.json',
              score: Score(
                notes: const [Note(midi: 67, duration: NoteDuration.quarter)],
              ),
            ),
          ],
        ),
      );
      addTearDown(harness.dispose);

      final firstLoad = harness.library.loadInitialWorkspace(
        initialScoreConfig: const ScoreSeedConfig.blank(),
      );
      await repository.waitForPendingSaveCount(1);

      final secondLoad = harness.library.loadInitialWorkspace(
        initialScoreConfig: const ScoreSeedConfig.preset('preset-1'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(repository.pendingSaves, hasLength(1));

      repository.completeSave(0);
      await repository.waitForPendingSaveCount(2);
      repository.completeSave(1);

      await secondLoad;
      await firstLoad;

      expect(repository.snapshot?.activePresetId, 'preset-1');
      expect(repository.snapshot?.draft.notes.single.midi, 67);
    },
  );
}

class _LibraryHarness {
  _LibraryHarness({
    _FakeAudioService? audioService,
    required ScoreLibraryRepository scoreLibraryRepository,
    required PresetScoreRepository presetScoreRepository,
  }) : session = EditableScoreSession(),
       workspaceRepository = DefaultWorkspaceRepository(
         scoreLibraryRepository: scoreLibraryRepository,
         presetScoreRepository: presetScoreRepository,
       ) {
    playback = PlaybackController(
      session: session,
      audioService: audioService ?? _FakeAudioService(),
    );
    editor = EditorController(session: session, notePreview: playback);
    library = ScoreLibraryController(
      session: session,
      playback: playback,
      workspaceRepository: workspaceRepository,
    );
  }

  final EditableScoreSession session;
  late final PlaybackController playback;
  late final EditorController editor;
  late final ScoreLibraryController library;
  final DefaultWorkspaceRepository workspaceRepository;

  void insertPitchedNote(int midi) {
    session.score.addNote(Note(midi: midi, duration: NoteDuration.quarter));
    session.markScoreChanged();
  }

  void setTempo(double bpm) {
    session.score.bpm = bpm;
    session.markScoreChanged();
  }

  void dispose() {
    editor.dispose();
    library.dispose();
    playback.dispose();
    session.dispose();
  }
}

void _dirtyEditorForReplacement(_LibraryHarness harness) {
  final editor = harness.editor;
  editor.setDuration(NoteDuration.half);
  editor.toggleDottedMode();
  editor.toggleSlurMode();
  editor.toggleTripletMode();
  harness.session.score.notes
    ..clear()
    ..addAll(const [
      Note(midi: 60, duration: NoteDuration.quarter),
      Note(midi: 62, duration: NoteDuration.quarter),
    ]);
  editor.selectNote(1);

  expect(editor.selectionKind, SelectionKind.note);
  expect(editor.selectedIndex, 1);
  expect(editor.currentDuration, NoteDuration.half);
  expect(editor.dottedMode, isTrue);
  expect(editor.slurMode, isTrue);
  expect(editor.tripletMode, isTrue);
}

void _expectEditorResetAfterReplacement(
  _LibraryHarness harness, {
  required String reason,
}) {
  final editor = harness.editor;
  expect(editor.selectionKind, isNull, reason: reason);
  expect(editor.selectedIndex, isNull, reason: reason);
  expect(editor.selectedNote, isNull, reason: reason);
  expect(
    editor.cursorIndex,
    harness.session.score.notes.length,
    reason: reason,
  );
  expect(editor.currentDuration, NoteDuration.quarter, reason: reason);
  expect(editor.dottedMode, isFalse, reason: reason);
  expect(editor.slurMode, isFalse, reason: reason);
  expect(editor.tripletMode, isFalse, reason: reason);
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

class _ControlledLoadScoreLibraryRepository implements ScoreLibraryRepository {
  final Completer<ScoreLibrarySnapshot?> _loadCompleter =
      Completer<ScoreLibrarySnapshot?>();
  ScoreLibrarySnapshot? snapshot;

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() {
    return _loadCompleter.future;
  }

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot nextSnapshot) async {
    snapshot = nextSnapshot;
  }

  void completeLoad(ScoreLibrarySnapshot? snapshot) {
    _loadCompleter.complete(snapshot);
  }
}

class _SequencedScoreLibraryRepository implements ScoreLibraryRepository {
  _SequencedScoreLibraryRepository(this._loadResults);

  final List<Future<ScoreLibrarySnapshot?>> _loadResults;
  int loadCalls = 0;
  ScoreLibrarySnapshot? snapshot;

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() {
    final result = _loadResults[loadCalls];
    loadCalls += 1;
    return result;
  }

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot nextSnapshot) async {
    snapshot = nextSnapshot;
  }
}

class _CountingSaveScoreLibraryRepository
    extends _MemoryScoreLibraryRepository {
  int saveCalls = 0;

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot nextSnapshot) async {
    saveCalls += 1;
    await super.saveSnapshot(nextSnapshot);
  }
}

class _ControlledSaveScoreLibraryRepository implements ScoreLibraryRepository {
  _ControlledSaveScoreLibraryRepository(this._loadResults);

  final List<Future<ScoreLibrarySnapshot?> Function()> _loadResults;
  int loadCalls = 0;
  Completer<void>? pendingSave;
  final List<Completer<void>> _pendingSaveWaiters = [];

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() {
    final result = _loadResults[loadCalls]();
    loadCalls += 1;
    return result;
  }

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot nextSnapshot) {
    pendingSave = Completer<void>();
    for (final waiter in List<Completer<void>>.from(_pendingSaveWaiters)) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _pendingSaveWaiters.clear();
    return pendingSave!.future;
  }

  Future<void> waitForPendingSave() async {
    while (pendingSave == null) {
      final waiter = Completer<void>();
      _pendingSaveWaiters.add(waiter);
      await waiter.future;
    }
  }
}

class _QueuedSaveScoreLibraryRepository implements ScoreLibraryRepository {
  ScoreLibrarySnapshot? snapshot;
  final List<_PendingSave> pendingSaves = [];
  final List<Completer<void>> _saveCountWaiters = [];

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot nextSnapshot) {
    final pendingSave = _PendingSave(nextSnapshot);
    pendingSaves.add(pendingSave);
    for (final waiter in List<Completer<void>>.from(_saveCountWaiters)) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _saveCountWaiters.clear();
    return pendingSave.completer.future;
  }

  Future<void> waitForPendingSaveCount(int count) async {
    while (pendingSaves.length < count) {
      final waiter = Completer<void>();
      _saveCountWaiters.add(waiter);
      await waiter.future;
    }
  }

  void completeSave(int index) {
    final pendingSave = pendingSaves[index];
    snapshot = pendingSave.snapshot;
    pendingSave.completer.complete();
  }
}

class _PendingSave {
  _PendingSave(this.snapshot);

  final ScoreLibrarySnapshot snapshot;
  final Completer<void> completer = Completer<void>();
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

class _FailingSaveScoreLibraryRepository implements ScoreLibraryRepository {
  _FailingSaveScoreLibraryRepository(this.snapshot);

  ScoreLibrarySnapshot? snapshot;

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot snapshot) async {
    throw const ScoreLibraryStorageException(
      'Failed to write the local score library.',
    );
  }
}

class _FakeAudioService extends AudioService {
  int preloadCalls = 0;

  @override
  Future<bool> init({
    Duration webTimeout = const Duration(seconds: 12),
  }) async => true;

  @override
  Future<bool> preload({
    Duration webTimeout = const Duration(seconds: 12),
  }) async {
    preloadCalls += 1;
    return true;
  }

  @override
  Future<void> stopNoteHandle(AudioNoteHandle handle) async {}

  @override
  void playRhythmTestMetronomeClick({required bool accented}) {}

  @override
  void stopPlayback() {}

  @override
  void dispose() {}
}
