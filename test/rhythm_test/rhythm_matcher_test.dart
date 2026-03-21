import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/rhythm_test/rhythm_matcher.dart';
import 'package:tap_score/rhythm_test/rhythm_test_models.dart';

void main() {
  const matcher = RhythmMatcher();

  test('matcher pairs taps in order within the one-pulse window', () {
    final result = matcher.match(
      expectedEvents: const [
        ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
        ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 1),
        ExpectedRhythmEvent(id: 3, noteIndex: 2, timeSeconds: 2),
      ],
      tapEvents: const [
        TapInputEvent(id: 1, timeSeconds: 0.05),
        TapInputEvent(id: 2, timeSeconds: 1.7),
        TapInputEvent(id: 3, timeSeconds: 2.1),
      ],
      matchingWindowSeconds: 0.3,
    );

    expect(result.matchedCount, 2);
    expect(result.appliedShiftSeconds, closeTo(0.05, 0.0001));
    expect(result.unmatchedExpectedEvents.map((event) => event.id), [2]);
    expect(result.unmatchedTapEvents.map((event) => event.id), [2]);
    expect(result.matchedPairs.map((pair) => pair.expected.id), [1, 3]);
  });

  test('matcher prefers more matches before lower total error', () {
    final result = matcher.match(
      expectedEvents: const [
        ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
        ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 1),
      ],
      tapEvents: const [
        TapInputEvent(id: 1, timeSeconds: 0.1),
        TapInputEvent(id: 2, timeSeconds: 0.95),
      ],
      matchingWindowSeconds: 0.2,
    );

    expect(result.matchedCount, 2);
    expect(result.appliedShiftSeconds, closeTo(-0.05, 0.0001));
    expect(result.unmatchedExpectedEvents, isEmpty);
    expect(result.unmatchedTapEvents, isEmpty);
    expect(result.averageAbsoluteErrorSeconds, closeTo(0.075, 0.0001));
  });

  test(
    'matcher keeps zero shift when there is not enough baseline evidence',
    () {
      final result = matcher.match(
        expectedEvents: const [
          ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
          ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 1),
        ],
        tapEvents: const [
          TapInputEvent(id: 1, timeSeconds: 0.08),
          TapInputEvent(id: 2, timeSeconds: 10.12),
        ],
        matchingWindowSeconds: 0.5,
      );

      expect(result.matchedCount, 1);
      expect(result.appliedShiftSeconds, 0);
      expect(result.unmatchedExpectedEvents.map((event) => event.id), [2]);
      expect(result.unmatchedTapEvents.map((event) => event.id), [2]);
      expect(result.averageAbsoluteErrorSeconds, closeTo(0.08, 0.0001));
    },
  );

  test('matcher applies a single global shift before scoring', () {
    final result = matcher.match(
      expectedEvents: const [
        ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
        ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 1),
        ExpectedRhythmEvent(id: 3, noteIndex: 2, timeSeconds: 2),
      ],
      tapEvents: const [
        TapInputEvent(id: 1, timeSeconds: 0.18),
        TapInputEvent(id: 2, timeSeconds: 1.18),
        TapInputEvent(id: 3, timeSeconds: 2.18),
      ],
      matchingWindowSeconds: 0.3,
    );

    expect(result.matchedCount, 3);
    expect(result.appliedShiftSeconds, closeTo(0.18, 0.0001));
    expect(result.shiftedAverageAbsoluteErrorSeconds, closeTo(0, 0.0001));
  });

  test('matcher shift optimization is not pulled by an outlier tap', () {
    final result = matcher.match(
      expectedEvents: const [
        ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
        ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 1),
        ExpectedRhythmEvent(id: 3, noteIndex: 2, timeSeconds: 2),
        ExpectedRhythmEvent(id: 4, noteIndex: 3, timeSeconds: 3),
      ],
      tapEvents: const [
        TapInputEvent(id: 1, timeSeconds: 0.2),
        TapInputEvent(id: 2, timeSeconds: 1.2),
        TapInputEvent(id: 3, timeSeconds: 2.2),
        TapInputEvent(id: 4, timeSeconds: 3.75),
      ],
      matchingWindowSeconds: 0.5,
    );

    expect(result.matchedCount, 3);
    expect(result.appliedShiftSeconds, closeTo(0.2, 0.0001));
    expect(result.unmatchedTapEvents.map((tap) => tap.id), [4]);
  });

  test('matcher keeps dense nearby taps aligned with a small shift', () {
    final result = matcher.match(
      expectedEvents: List.generate(
        12,
        (index) => ExpectedRhythmEvent(
          id: index,
          noteIndex: index,
          timeSeconds: index.toDouble(),
        ),
      ),
      tapEvents: List.generate(
        12,
        (index) => TapInputEvent(
          id: index,
          timeSeconds: index + (index.isEven ? 0.08 : 0.12),
        ),
      ),
      matchingWindowSeconds: 1,
    );

    expect(result.matchedCount, 12);
    expect(result.appliedShiftSeconds, closeTo(0.08, 0.0001));
    expect(result.shiftedAverageAbsoluteErrorSeconds, greaterThan(0));
    expect(result.shiftedAverageAbsoluteErrorSeconds, lessThan(0.05));
  });

  test('matcher does not trade most near hits for a huge perfect shift', () {
    final result = matcher.match(
      expectedEvents: List.generate(
        12,
        (index) => ExpectedRhythmEvent(
          id: index,
          noteIndex: index,
          timeSeconds: index.toDouble(),
        ),
      ),
      tapEvents: const [
        TapInputEvent(id: 0, timeSeconds: 0.080),
        TapInputEvent(id: 1, timeSeconds: 1.171),
        TapInputEvent(id: 2, timeSeconds: 2.182),
        TapInputEvent(id: 3, timeSeconds: 3.094),
        TapInputEvent(id: 4, timeSeconds: 4.208),
        TapInputEvent(id: 5, timeSeconds: 5.082),
        TapInputEvent(id: 6, timeSeconds: 6.132),
        TapInputEvent(id: 7, timeSeconds: 7.085),
        TapInputEvent(id: 8, timeSeconds: 8.091),
        TapInputEvent(id: 9, timeSeconds: 9.165),
        TapInputEvent(id: 10, timeSeconds: 10.215),
        TapInputEvent(id: 11, timeSeconds: 11.119),
      ],
      matchingWindowSeconds: 1,
    );

    expect(result.matchedCount, 12);
    expect(result.appliedShiftSeconds.abs(), lessThan(0.3));
    expect(result.shiftedAverageAbsoluteErrorSeconds, greaterThan(0));
  });

  test('matcher returns zero shift when there are no tap candidates', () {
    final result = matcher.match(
      expectedEvents: const [
        ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
        ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 1),
      ],
      tapEvents: const [],
      matchingWindowSeconds: 0.2,
    );

    expect(result.matchedCount, 0);
    expect(result.appliedShiftSeconds, 0);
    expect(result.shiftedAverageAbsoluteErrorSeconds, isNull);
  });
}
