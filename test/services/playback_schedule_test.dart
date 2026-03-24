import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/services/playback_schedule.dart';

void main() {
  test(
    'same-pitch notes without a connection stay as separate playback notes',
    () {
      final timeline = buildScorePlaybackTimeline(
        Score(
          bpm: 60,
          notes: const [
            Note(midi: 60, duration: NoteDuration.quarter),
            Note(midi: 60, duration: NoteDuration.quarter),
          ],
        ),
      );

      expect(timeline.playbackNotes, hasLength(2));
      expect(timeline.playbackNotes.map((note) => note.noteIndex), [0, 1]);
      expect(timeline.playbackNotes.map((note) => note.durationSeconds), [
        1.0,
        1.0,
      ]);
    },
  );

  test('same-pitch connected notes merge into one playback note', () {
    final timeline = buildScorePlaybackTimeline(
      Score(
        bpm: 60,
        notes: const [
          Note(midi: 60, duration: NoteDuration.quarter, slurToNext: true),
          Note(midi: 60, duration: NoteDuration.quarter),
        ],
      ),
    );

    expect(timeline.steps, hasLength(2));
    expect(timeline.playbackNotes, hasLength(1));
    expect(timeline.playbackNotes.single.noteIndex, 0);
    expect(timeline.playbackNotes.single.startSeconds, 0.0);
    expect(timeline.playbackNotes.single.durationSeconds, 2.0);
  });

  test('multi-segment tie chain merges into one playback note', () {
    final timeline = buildScorePlaybackTimeline(
      Score(
        bpm: 60,
        notes: const [
          Note(midi: 60, duration: NoteDuration.eighth, slurToNext: true),
          Note(midi: 60, duration: NoteDuration.eighth, slurToNext: true),
          Note(midi: 60, duration: NoteDuration.quarter),
        ],
      ),
    );

    expect(timeline.playbackNotes, hasLength(1));
    expect(timeline.playbackNotes.single.noteIndex, 0);
    expect(timeline.playbackNotes.single.durationSeconds, 2.0);
  });

  test('different-pitch slur does not merge playback notes', () {
    final timeline = buildScorePlaybackTimeline(
      Score(
        bpm: 60,
        notes: const [
          Note(midi: 60, duration: NoteDuration.quarter, slurToNext: true),
          Note(midi: 62, duration: NoteDuration.quarter),
        ],
      ),
    );

    expect(timeline.playbackNotes, hasLength(2));
    expect(timeline.playbackNotes.map((note) => note.noteIndex), [0, 1]);
  });
}
