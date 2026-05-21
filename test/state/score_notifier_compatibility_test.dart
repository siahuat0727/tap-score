import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/app/score_seed_config.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/portable_score_document.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';
import 'package:tap_score/services/audio_service.dart';
import 'package:tap_score/services/score_library_repository.dart';
import 'package:tap_score/state/score_notifier.dart';
import 'package:tap_score/workspace/workspace_document.dart';
import 'package:tap_score/workspace/workspace_repository.dart';
import 'package:tap_score/workspace/workspace_session.dart';

void main() {
  test(
    'library loads reset editor state before notifier listeners run',
    () async {
      final repository = _ShortScoreLoadRepository();
      final notifier = ScoreNotifier(workspaceRepository: repository);
      addTearDown(notifier.dispose);

      await notifier.loadInitialWorkspace();
      notifier.selectNote(1);

      var observedInvalidSelection = false;
      notifier.addListener(() {
        final selectedIndex = notifier.selectedIndex;
        if (selectedIndex != null &&
            selectedIndex >= notifier.score.notes.length) {
          observedInvalidSelection = true;
        }
        notifier.selectedNote;
      });

      await notifier.loadSavedScore('short');

      expect(observedInvalidSelection, isFalse);
      expect(notifier.selectedIndex, isNull);
      expect(notifier.score.notes, hasLength(1));
    },
  );

  test(
    'failed library loads keep editor state when no score was replaced',
    () async {
      final repository = _ShortScoreLoadRepository();
      final notifier = ScoreNotifier(workspaceRepository: repository);
      addTearDown(notifier.dispose);

      await notifier.loadInitialWorkspace();
      notifier.selectNote(1);

      await notifier.loadSavedScore('storage-error');

      expect(notifier.selectedIndex, 1);
      expect(notifier.selectedNote?.midi, 62);
      expect(notifier.libraryMessage, 'Failed to load saved score.');
      expect(notifier.libraryMessageIsError, isTrue);
    },
  );

  test(
    'thrown library loads still notify suppressed playback state changes',
    () async {
      final repository = _ShortScoreLoadRepository();
      final audioService = _HoldingAudioService();
      final notifier = ScoreNotifier(
        workspaceRepository: repository,
        audioService: audioService,
      );
      addTearDown(notifier.dispose);

      await notifier.loadInitialWorkspace();
      final playback = notifier.play();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isPlaying, isTrue);

      var observedStopped = false;
      notifier.addListener(() {
        if (!notifier.isPlaying) {
          observedStopped = true;
        }
      });

      await expectLater(
        notifier.loadSavedScore('missing'),
        throwsArgumentError,
      );
      await playback;

      expect(observedStopped, isTrue);
      expect(notifier.isPlaying, isFalse);
    },
  );

  test(
    'overlapping library loads keep notifications suppressed until reset',
    () async {
      final repository = _ControlledSavedScoreLoadRepository();
      final notifier = ScoreNotifier(workspaceRepository: repository);
      addTearDown(notifier.dispose);

      await notifier.loadInitialWorkspace();
      notifier.selectNote(1);

      var observedInvalidSelection = false;
      notifier.addListener(() {
        final selectedIndex = notifier.selectedIndex;
        if (selectedIndex != null &&
            selectedIndex >= notifier.score.notes.length) {
          observedInvalidSelection = true;
        }
        notifier.selectedNote;
      });

      final failedLoad = notifier.loadSavedScore('missing');
      await Future<void>.delayed(Duration.zero);
      final successfulLoad = notifier.loadSavedScore('short');
      await Future<void>.delayed(Duration.zero);

      repository.complete('missing');
      await expectLater(failedLoad, throwsArgumentError);
      repository.complete('short');
      await successfulLoad;

      expect(observedInvalidSelection, isFalse);
      expect(notifier.selectedIndex, isNull);
      expect(notifier.score.notes, hasLength(1));
    },
  );
}

class _ShortScoreLoadRepository extends WorkspaceRepository {
  final SavedScoreEntry _shortScore = SavedScoreEntry(
    id: 'short',
    name: 'Short',
    updatedAt: DateTime.utc(2026, 5, 20),
    score: Score(notes: const [Note(midi: 60)]),
  );

  @override
  Future<WorkspaceLoadResult> loadWorkspace({
    ScoreSeedConfig? initialScoreConfig,
  }) async {
    final initialScore = Score(notes: const [Note(midi: 60), Note(midi: 62)]);
    return WorkspaceLoadResult(
      workspace: WorkspaceSession(
        editorScore: initialScore,
        document: WorkspaceDocument.draft(score: initialScore),
        savedScores: [_shortScore],
        presetScores: const [],
      ),
    );
  }

  @override
  Future<WorkspaceSession> loadSavedScore({
    required WorkspaceSession workspace,
    required String id,
  }) async {
    if (id == 'storage-error') {
      throw const ScoreLibraryStorageException('Failed to load saved score.');
    }
    if (id != _shortScore.id) {
      throw WorkspaceRepositoryException('Saved score "$id" does not exist.');
    }
    return WorkspaceSession(
      editorScore: _shortScore.score.copy(),
      document: WorkspaceDocument.saved(_shortScore),
      savedScores: workspace.savedScores,
      presetScores: workspace.presetScores,
    );
  }

  @override
  Future<WorkspaceLoadResult> restoreDraft() {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceSession> saveCurrentScore({
    required WorkspaceSession workspace,
    required Score editedScore,
    required String name,
    bool createNew = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceSession> loadPresetScore({
    required WorkspaceSession workspace,
    required String id,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceSession> importDocument({
    required WorkspaceSession workspace,
    required PortableScoreDocument document,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkspaceSession> deleteSavedScore({
    required WorkspaceSession workspace,
    required String id,
    required Score currentScore,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> persistDraft({
    required WorkspaceSession workspace,
    required Score editedScore,
  }) async {}
}

class _ControlledSavedScoreLoadRepository extends _ShortScoreLoadRepository {
  final Map<String, Completer<void>> _loads = {};

  @override
  Future<WorkspaceSession> loadSavedScore({
    required WorkspaceSession workspace,
    required String id,
  }) async {
    final completer = Completer<void>();
    _loads[id] = completer;
    await completer.future;
    return super.loadSavedScore(workspace: workspace, id: id);
  }

  void complete(String id) {
    final completer = _loads[id];
    if (completer == null) {
      throw StateError('No pending load for $id.');
    }
    completer.complete();
  }
}

class _HoldingAudioService extends AudioService {
  Completer<void>? _pendingPlayback;

  @override
  Future<void> playScore(
    Score score, {
    required void Function(int index) onNoteIndex,
    required void Function() onComplete,
  }) async {
    onNoteIndex(0);
    final pendingPlayback = Completer<void>();
    _pendingPlayback = pendingPlayback;
    await pendingPlayback.future;
    _pendingPlayback = null;
    onComplete();
  }

  @override
  void stopPlayback() {
    final pendingPlayback = _pendingPlayback;
    if (pendingPlayback != null && !pendingPlayback.isCompleted) {
      pendingPlayback.complete();
    }
  }

  @override
  void dispose() {
    stopPlayback();
  }
}
