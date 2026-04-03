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
import 'package:tap_score/state/score_notifier.dart';

void main() {
  test(
    'init restores the persisted draft and active score reference',
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
      final notifier = ScoreNotifier(
        audioService: _FakeAudioService(),
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(notifier.dispose);

      await notifier.init();

      expect(notifier.score.notes.single.midi, 65);
      expect(notifier.score.bpm, 88);
      expect(notifier.activeScoreId, 'saved-1');
      expect(notifier.currentScoreLabel, 'Warmup');
      expect(notifier.hasUnsavedChanges, isFalse);
    },
  );

  test(
    'save as new stores multiple named scores and load restores each',
    () async {
      final repository = _MemoryScoreLibraryRepository();
      final notifier = ScoreNotifier(
        audioService: _FakeAudioService(),
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(notifier.dispose);

      await notifier.init();

      notifier.insertPitchedNote(60);
      await notifier.saveCurrentScore('First');

      notifier.setTempo(144);
      await notifier.saveCurrentScore('Second', createNew: true);

      expect(notifier.savedScores, hasLength(2));
      final first = notifier.savedScores.firstWhere(
        (entry) => entry.name == 'First',
      );
      final second = notifier.savedScores.firstWhere(
        (entry) => entry.name == 'Second',
      );
      expect(first.id, isNot(second.id));

      await notifier.loadSavedScore(first.id);
      expect(notifier.score.bpm, 120);
      expect(notifier.activeScoreId, first.id);
      expect(notifier.currentScoreLabel, 'First');

      await notifier.loadSavedScore(second.id);
      expect(notifier.score.bpm, 144);
      expect(notifier.activeScoreId, second.id);
      expect(notifier.currentScoreLabel, 'Second');
    },
  );

  test(
    'delete clears the active saved reference when removing the current score',
    () async {
      final repository = _MemoryScoreLibraryRepository();
      final notifier = ScoreNotifier(
        audioService: _FakeAudioService(),
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(notifier.dispose);

      await notifier.init();

      notifier.insertPitchedNote(72);
      await notifier.saveCurrentScore('Solo');
      final savedId = notifier.activeScoreId!;

      await notifier.deleteSavedScore(savedId);

      expect(notifier.savedScores, isEmpty);
      expect(notifier.activeScoreId, isNull);
      expect(notifier.currentScoreLabel, 'Draft');
      expect(notifier.hasUnsavedChanges, isFalse);
    },
  );

  test('init loads presets alongside saved scores', () async {
    final notifier = ScoreNotifier(
      audioService: _FakeAudioService(),
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
    addTearDown(notifier.dispose);

    await notifier.init();

    expect(notifier.presetScores, hasLength(1));
    expect(notifier.presetScores.single.name, 'Warmup');
  });

  test(
    'imported documents become draft without an active saved score',
    () async {
      final repository = _MemoryScoreLibraryRepository();
      final notifier = ScoreNotifier(
        audioService: _FakeAudioService(),
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(notifier.dispose);

      await notifier.init();
      await notifier.importScoreDocument(
        PortableScoreDocument(
          version: PortableScoreDocument.currentVersion,
          name: 'Imported Etude',
          score: Score(
            notes: const [Note(midi: 72, duration: NoteDuration.whole)],
            bpm: 72,
          ),
        ),
      );

      expect(notifier.activeScoreId, isNull);
      expect(notifier.currentScoreLabel, 'Imported Etude');
      expect(notifier.hasUnsavedChanges, isFalse);
      expect(repository.snapshot?.draft.bpm, 72);
    },
  );

  test('loading a preset does not add it to saved scores', () async {
    final notifier = ScoreNotifier(
      audioService: _FakeAudioService(),
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
    addTearDown(notifier.dispose);

    await notifier.init();
    await notifier.loadPresetScore('preset-1');

    expect(notifier.activeScoreId, isNull);
    expect(notifier.activePresetId, 'preset-1');
    expect(notifier.savedScores, isEmpty);
    expect(notifier.currentScoreLabel, 'Triplet Study');
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
      final notifier = ScoreNotifier(
        audioService: audioService,
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(notifier.dispose);

      await notifier.init(initialScoreConfig: const ScoreSeedConfig.blank());

      expect(notifier.score.notes, isEmpty);
      expect(notifier.activeScoreId, isNull);
      expect(notifier.activePresetId, isNull);
      expect(notifier.savedScores, hasLength(1));
      expect(notifier.currentScoreLabel, 'Draft');
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
      final notifier = ScoreNotifier(
        audioService: _FakeAudioService(),
        scoreLibraryRepository: repository,
        presetScoreRepository: _MemoryPresetScoreRepository(),
      );
      addTearDown(notifier.dispose);

      await notifier.init(initialScoreConfig: const ScoreSeedConfig.blank());
      await Future<void>.delayed(Duration.zero);

      expect(notifier.score.notes, isEmpty);
      expect(notifier.currentScoreLabel, 'Draft');
      expect(
        notifier.libraryMessage,
        'Failed to write the local score library.',
      );
      expect(notifier.libraryMessageIsError, isTrue);
    },
  );

  test(
    'blank launch falls back to local state when preset loading fails',
    () async {
      final notifier = ScoreNotifier(
        audioService: _FakeAudioService(),
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
      addTearDown(notifier.dispose);

      await notifier.init();

      expect(notifier.score.notes.single.midi, 65);
      expect(notifier.activeScoreId, 'saved-1');
      expect(notifier.currentScoreLabel, 'Warmup');
      expect(notifier.libraryMessage, 'Failed to load preset score manifest.');
      expect(notifier.libraryMessageIsError, isTrue);
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
      final notifier = ScoreNotifier(
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
      addTearDown(notifier.dispose);

      await notifier.init(
        initialScoreConfig: const ScoreSeedConfig.preset('preset-1'),
      );

      expect(notifier.score.notes, hasLength(1));
      expect(notifier.score.notes.single.midi, 67);
      expect(notifier.activeScoreId, isNull);
      expect(notifier.activePresetId, 'preset-1');
      expect(notifier.savedScores, hasLength(1));
      expect(notifier.currentScoreLabel, 'Triplet Study');
      expect(audioService.preloadCalls, 0);
      expect(repository.snapshot?.draft.notes.single.midi, 67);
    },
  );
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
  Future<bool> init() async => true;

  @override
  Future<bool> preload() async {
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
