import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/rhythm_test/rhythm_matcher.dart';
import 'package:tap_score/rhythm_test/rhythm_test_models.dart';

void main() {
  const matcher = RhythmMatcher();

  test('matcher only matches taps within the one-beat window', () {
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
    expect(result.appliedShiftSeconds, 0);
    expect(result.unmatchedExpectedEvents.map((event) => event.id), [2]);
    expect(result.unmatchedTapEvents.map((event) => event.id), [2]);
    expect(result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]), [
      [1, 1],
      [3, 3],
    ]);
  });

  test('matcher maximizes match count before minimizing error', () {
    final result = matcher.match(
      expectedEvents: const [
        ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0.00),
        ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.50),
      ],
      tapEvents: const [
        TapInputEvent(id: 1, timeSeconds: 0.45),
        TapInputEvent(id: 2, timeSeconds: 0.55),
      ],
      matchingWindowSeconds: 0.5,
    );

    expect(result.matchedCount, 2);
    expect(result.appliedShiftSeconds, 0);
    expect(result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]), [
      [1, 1],
      [2, 2],
    ]);
    expect(result.averageAbsoluteErrorSeconds, closeTo(0.25, 0.0001));
  });

  test(
    'matcher minimizes total error among maximum-cardinality assignments',
    () {
      final result = matcher.match(
        expectedEvents: const [
          ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0.00),
          ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.25),
          ExpectedRhythmEvent(id: 3, noteIndex: 2, timeSeconds: 0.50),
        ],
        tapEvents: const [
          TapInputEvent(id: 1, timeSeconds: 0.24),
          TapInputEvent(id: 2, timeSeconds: 0.26),
          TapInputEvent(id: 3, timeSeconds: 0.74),
        ],
        matchingWindowSeconds: 0.3,
      );

      expect(result.matchedCount, 3);
      expect(
        result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]),
        [
          [1, 1],
          [2, 2],
          [3, 3],
        ],
      );
      expect(result.totalAbsoluteErrorSeconds, closeTo(0.49, 0.0001));
    },
  );

  test('matcher leaves outlier taps unmatched when they exceed one beat', () {
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
        TapInputEvent(id: 4, timeSeconds: 4.2),
      ],
      matchingWindowSeconds: 0.5,
    );

    expect(result.matchedCount, 3);
    expect(result.unmatchedExpectedEvents.map((event) => event.id), [4]);
    expect(result.unmatchedTapEvents.map((tap) => tap.id), [4]);
  });

  test(
    'matcher keeps pairings ordered and does not allow crossing matches',
    () {
      final result = matcher.match(
        expectedEvents: const [
          ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0.0),
          ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 1.0),
        ],
        tapEvents: const [
          TapInputEvent(id: 1, timeSeconds: 0.8),
          TapInputEvent(id: 2, timeSeconds: 0.2),
        ],
        matchingWindowSeconds: 1.0,
      );

      expect(result.matchedCount, 2);
      expect(
        result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]),
        [
          [1, 1],
          [2, 2],
        ],
      );
    },
  );

  test(
    'matcher keeps dense sixteenth notes on the same sequence when all taps are slightly late',
    () {
      final result = matcher.match(
        expectedEvents: const [
          ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0.00),
          ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.25),
          ExpectedRhythmEvent(id: 3, noteIndex: 2, timeSeconds: 0.50),
          ExpectedRhythmEvent(id: 4, noteIndex: 3, timeSeconds: 0.75),
        ],
        tapEvents: const [
          TapInputEvent(id: 1, timeSeconds: 0.18),
          TapInputEvent(id: 2, timeSeconds: 0.43),
          TapInputEvent(id: 3, timeSeconds: 0.68),
          TapInputEvent(id: 4, timeSeconds: 0.93),
        ],
        matchingWindowSeconds: 1,
      );

      expect(result.matchedCount, 4);
      expect(result.appliedShiftSeconds, 0);
      expect(
        result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]),
        [
          [1, 1],
          [2, 2],
          [3, 3],
          [4, 4],
        ],
      );
      expect(result.unmatchedExpectedEvents, isEmpty);
      expect(result.unmatchedTapEvents, isEmpty);
    },
  );

  test(
    'matcher can match a dense group when each tap is less than one beat late',
    () {
      final result = matcher.match(
        expectedEvents: const [
          ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0.00),
          ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.25),
          ExpectedRhythmEvent(id: 3, noteIndex: 2, timeSeconds: 0.50),
          ExpectedRhythmEvent(id: 4, noteIndex: 3, timeSeconds: 0.75),
        ],
        tapEvents: const [
          TapInputEvent(id: 1, timeSeconds: 0.92),
          TapInputEvent(id: 2, timeSeconds: 1.17),
          TapInputEvent(id: 3, timeSeconds: 1.42),
          TapInputEvent(id: 4, timeSeconds: 1.67),
        ],
        matchingWindowSeconds: 1,
      );

      expect(result.matchedCount, 4);
      expect(
        result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]),
        [
          [1, 1],
          [2, 2],
          [3, 3],
          [4, 4],
        ],
      );
    },
  );

  test(
    'matcher uses squared error to break ties after match count and absolute error',
    () {
      final result = matcher.match(
        expectedEvents: const [
          ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0.0),
          ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.2),
          ExpectedRhythmEvent(id: 3, noteIndex: 2, timeSeconds: 0.8),
        ],
        tapEvents: const [
          TapInputEvent(id: 1, timeSeconds: 0.2),
          TapInputEvent(id: 2, timeSeconds: 0.4),
          TapInputEvent(id: 3, timeSeconds: 2.0),
        ],
        matchingWindowSeconds: 1.0,
      );

      expect(result.matchedCount, 2);
      expect(result.totalAbsoluteErrorSeconds, closeTo(0.4, 0.0001));
      expect(
        result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]),
        [
          [1, 1],
          [2, 2],
        ],
      );
    },
  );

  test('matcher does not match taps that are more than one beat late', () {
    final result = matcher.match(
      expectedEvents: const [
        ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0.00),
        ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 1.00),
      ],
      tapEvents: const [
        TapInputEvent(id: 1, timeSeconds: 1.01),
        TapInputEvent(id: 2, timeSeconds: 2.01),
      ],
      matchingWindowSeconds: 1,
    );

    expect(result.matchedCount, 1);
    expect(result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]), [
      [2, 1],
    ]);
    expect(result.unmatchedExpectedEvents.map((event) => event.id), [1]);
    expect(result.unmatchedTapEvents.map((tap) => tap.id), [2]);
  });

  test('matcher preserves results across disconnected timing components', () {
    final result = matcher.match(
      expectedEvents: const [
        ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0.00),
        ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.25),
        ExpectedRhythmEvent(id: 3, noteIndex: 2, timeSeconds: 3.00),
        ExpectedRhythmEvent(id: 4, noteIndex: 3, timeSeconds: 3.25),
      ],
      tapEvents: const [
        TapInputEvent(id: 1, timeSeconds: 0.08),
        TapInputEvent(id: 2, timeSeconds: 0.34),
        TapInputEvent(id: 3, timeSeconds: 3.06),
        TapInputEvent(id: 4, timeSeconds: 3.31),
      ],
      matchingWindowSeconds: 0.2,
    );

    expect(result.matchedCount, 4);
    expect(result.matchedPairs.map((pair) => [pair.expected.id, pair.tap.id]), [
      [1, 1],
      [2, 2],
      [3, 3],
      [4, 4],
    ]);
    expect(result.unmatchedExpectedEvents, isEmpty);
    expect(result.unmatchedTapEvents, isEmpty);
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
