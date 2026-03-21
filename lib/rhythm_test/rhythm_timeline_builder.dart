import '../models/score.dart';
import 'rhythm_test_models.dart';

class RhythmTimelineBuilder {
  const RhythmTimelineBuilder();

  RhythmTimeline build(Score score) {
    final expectedEvents = <ExpectedRhythmEvent>[];
    var elapsedSeconds = 0.0;
    var nextId = 0;

    for (var index = 0; index < score.notes.length; index++) {
      final note = score.notes[index];
      if (!note.isRest) {
        expectedEvents.add(
          ExpectedRhythmEvent(
            id: nextId++,
            noteIndex: index,
            timeSeconds: elapsedSeconds,
          ),
        );
      }

      elapsedSeconds += note.effectiveBeats * score.secondsPerQuarterNote;
    }

    final measureBoundaries = <double>[0];
    final measureDuration = score.measureDurationSeconds;
    while (measureBoundaries.last < elapsedSeconds) {
      measureBoundaries.add(measureBoundaries.last + measureDuration);
    }

    if (measureBoundaries.last > elapsedSeconds) {
      measureBoundaries[measureBoundaries.length - 1] = elapsedSeconds;
    }

    return RhythmTimeline(
      expectedEvents: expectedEvents,
      measureBoundaryTimesSeconds: measureBoundaries,
      totalDurationSeconds: elapsedSeconds,
      pulseDurationSeconds: score.pulseDurationSeconds,
      pulsesPerMeasure: score.beatsPerMeasure,
    );
  }
}
