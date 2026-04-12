import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/rhythm_test/rhythm_test_models.dart';

void main() {
  test('result error and max error stats include misses and extra taps', () {
    const result = RhythmTestResult(
      matchedPairs: [
        MatchedRhythmPair(
          expected: ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
          tap: TapInputEvent(id: 1, timeSeconds: 0.03),
          errorSeconds: 0.03,
        ),
        MatchedRhythmPair(
          expected: ExpectedRhythmEvent(id: 2, noteIndex: 2, timeSeconds: 1),
          tap: TapInputEvent(id: 2, timeSeconds: 1.14),
          errorSeconds: 0.14,
        ),
      ],
      unmatchedExpectedEvents: [
        ExpectedRhythmEvent(id: 3, noteIndex: 4, timeSeconds: 2),
      ],
      unmatchedTapEvents: [TapInputEvent(id: 3, timeSeconds: 2.8)],
      matchingWindowSeconds: 0.5,
      appliedShiftSeconds: 0,
    );

    expect(result.errorCount, 2);
    expect(result.maxAbsoluteErrorSeconds, closeTo(0.14, 0.0001));
    expect(result.missedExpectedNoteIndices, [4]);
  });

  test(
    'result large error helpers only include matched pairs over threshold',
    () {
      const result = RhythmTestResult(
        matchedPairs: [
          MatchedRhythmPair(
            expected: ExpectedRhythmEvent(id: 1, noteIndex: 1, timeSeconds: 0),
            tap: TapInputEvent(id: 1, timeSeconds: 0.04),
            errorSeconds: 0.04,
          ),
          MatchedRhythmPair(
            expected: ExpectedRhythmEvent(id: 2, noteIndex: 3, timeSeconds: 1),
            tap: TapInputEvent(id: 2, timeSeconds: 1.12),
            errorSeconds: 0.12,
          ),
        ],
        unmatchedExpectedEvents: [],
        unmatchedTapEvents: [],
        matchingWindowSeconds: 0.5,
        appliedShiftSeconds: 0,
      );

      expect(result.largeErrorCountForThreshold(0.1), 1);
      expect(result.largeErrorExpectedNoteIndicesForThreshold(0.1), [3]);
    },
  );

  test('result display tap helpers subtract the applied shift', () {
    const result = RhythmTestResult(
      matchedPairs: [],
      unmatchedExpectedEvents: [],
      unmatchedTapEvents: [],
      matchingWindowSeconds: 0.5,
      appliedShiftSeconds: 0.2,
    );
    const rawTap = TapInputEvent(id: 7, timeSeconds: 1.35);

    expect(result.displayTimeSecondsForTap(rawTap), closeTo(1.15, 0.0001));
    expect(result.displayTapEvent(rawTap).timeSeconds, closeTo(1.15, 0.0001));
    expect(result.displayTapEvent(rawTap).id, rawTap.id);
  });
}
