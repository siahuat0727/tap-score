import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/rhythm_test/rhythm_timeline_builder.dart';

void main() {
  const builder = RhythmTimelineBuilder();

  test('timeline builder keeps only non-rest note onsets', () {
    final score = Score(
      bpm: 60,
      notes: [
        const Note(midi: 60, duration: NoteDuration.quarter),
        const Note.rest(duration: NoteDuration.eighth),
        const Note(midi: 62, duration: NoteDuration.quarter, isDotted: true),
      ],
    );

    final timeline = builder.build(score);

    expect(timeline.expectedEvents, hasLength(2));
    expect(timeline.expectedEvents[0].timeSeconds, 0);
    expect(timeline.expectedEvents[1].timeSeconds, 1.5);
    expect(timeline.totalDurationSeconds, 3.0);
    expect(timeline.pulseDurationSeconds, 1.0);
    expect(timeline.matchingWindowSeconds, 1.0);
  });

  test('timeline builder uses denominator pulses for compound meters', () {
    final score = Score(
      beatsPerMeasure: 6,
      beatUnit: 8,
      bpm: 120,
      notes: [
        const Note(midi: 60, duration: NoteDuration.eighth),
        const Note(midi: 62, duration: NoteDuration.eighth),
        const Note(midi: 64, duration: NoteDuration.quarter),
      ],
    );

    final timeline = builder.build(score);

    expect(timeline.pulsesPerMeasure, 6);
    expect(timeline.expectedEvents.map((event) => event.timeSeconds), [
      0.0,
      0.25,
      0.5,
    ]);
    expect(timeline.pulseDurationSeconds, 0.25);
    expect(timeline.totalDurationSeconds, 1.0);
  });
}
