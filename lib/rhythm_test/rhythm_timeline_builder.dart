import '../models/score.dart';
import '../services/playback_schedule.dart';
import 'rhythm_test_models.dart';

class RhythmTimelineBuilder {
  const RhythmTimelineBuilder();

  static const int rhythmTestMelodyVelocity = 90;

  RhythmTimeline build(Score score) {
    final playbackTimeline = buildScorePlaybackTimeline(
      score,
      velocity: rhythmTestMelodyVelocity,
    );
    final expectedEvents = <ExpectedRhythmEvent>[];
    var nextId = 0;
    for (final note in playbackTimeline.playbackNotes) {
      expectedEvents.add(
        ExpectedRhythmEvent(
          id: nextId++,
          noteIndex: note.noteIndex,
          timeSeconds: note.startSeconds,
        ),
      );
    }

    final measureBoundaries = <double>[0];
    final measureDuration = score.measureDurationSeconds;
    while (measureBoundaries.last < playbackTimeline.totalDurationSeconds) {
      measureBoundaries.add(measureBoundaries.last + measureDuration);
    }

    if (measureBoundaries.last > playbackTimeline.totalDurationSeconds) {
      measureBoundaries[measureBoundaries.length - 1] =
          playbackTimeline.totalDurationSeconds;
    }

    return RhythmTimeline(
      expectedEvents: expectedEvents,
      playbackNotes: playbackTimeline.playbackNotes,
      measureBoundaryTimesSeconds: measureBoundaries,
      totalDurationSeconds: playbackTimeline.totalDurationSeconds,
      pulseDurationSeconds: score.pulseDurationSeconds,
      pulsesPerMeasure: score.beatsPerMeasure,
    );
  }
}
