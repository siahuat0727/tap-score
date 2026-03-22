import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/key_signature.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/portable_score_document.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';

void main() {
  test('score round-trips through json', () {
    final score = Score(
      notes: const [
        Note(
          midi: 64,
          duration: NoteDuration.eighth,
          isDotted: true,
          tripletGroupId: 7,
          slurToNext: true,
        ),
        Note.rest(
          duration: NoteDuration.sixteenth,
          tripletGroupId: 9,
          sourceMidi: 72,
        ),
      ],
      beatsPerMeasure: 6,
      beatUnit: 8,
      bpm: 92,
      keySignature: KeySignature.ebMajor,
    );

    final decoded = Score.fromJson(score.toJson());

    expect(decoded, score);
  });

  test('score library snapshot round-trips through json', () {
    final snapshot = ScoreLibrarySnapshot(
      draft: Score(
        notes: const [
          Note(midi: 60, duration: NoteDuration.quarter),
          Note.rest(duration: NoteDuration.eighth, isDotted: true),
        ],
        bpm: 144,
        keySignature: KeySignature.gMajor,
      ),
      savedScores: [
        SavedScoreEntry(
          id: 'score-1',
          name: 'Etude',
          updatedAt: DateTime.utc(2026, 3, 22, 10, 0, 0),
          score: Score(
            notes: const [Note(midi: 67, duration: NoteDuration.half)],
          ),
        ),
      ],
      activeScoreId: 'score-1',
    );

    final decoded = ScoreLibrarySnapshot.fromJson(snapshot.toJson());

    expect(decoded.draft, snapshot.draft);
    expect(decoded.savedScores.single.id, 'score-1');
    expect(decoded.savedScores.single.name, 'Etude');
    expect(decoded.savedScores.single.score, snapshot.savedScores.single.score);
    expect(decoded.activeScoreId, 'score-1');
  });

  test('portable score document round-trips through json', () {
    final document = PortableScoreDocument(
      version: PortableScoreDocument.currentVersion,
      name: 'Triplet Study',
      score: Score(
        notes: const [
          Note(midi: 67, duration: NoteDuration.quarter, tripletGroupId: 5),
        ],
        bpm: 96,
        keySignature: KeySignature.gMajor,
      ),
    );

    final decoded = PortableScoreDocument.fromJson(document.toJson());

    expect(decoded.version, PortableScoreDocument.currentVersion);
    expect(decoded.name, 'Triplet Study');
    expect(decoded.score, document.score);
  });

  test('portable score document rejects unsupported versions', () {
    expect(
      () => PortableScoreDocument.fromJson({
        'version': 99,
        'name': 'Broken',
        'score': Score().toJson(),
      }),
      throwsArgumentError,
    );
  });
}
