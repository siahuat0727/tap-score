import 'rhythm_test_models.dart';

class RhythmMatcher {
  static const double _comparisonTolerance = 1e-9;

  const RhythmMatcher();

  RhythmTestResult match({
    required List<ExpectedRhythmEvent> expectedEvents,
    required List<TapInputEvent> tapEvents,
    required double matchingWindowSeconds,
  }) {
    final rows = expectedEvents.length + 1;
    final columns = tapEvents.length + 1;
    final dp = List<List<_MatchState?>>.generate(
      rows,
      (_) => List<_MatchState?>.filled(columns, null),
    );
    final decisions = List<List<_Decision?>>.generate(
      rows,
      (_) => List<_Decision?>.filled(columns, null),
    );

    dp[0][0] = const _MatchState(
      matchedCount: 0,
      totalAbsoluteErrorSeconds: 0,
      totalSquaredErrorSeconds: 0,
    );

    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < columns; j++) {
        final current = dp[i][j];
        if (current == null) {
          continue;
        }

        if (i < expectedEvents.length) {
          _updateState(
            dp: dp,
            decisions: decisions,
            row: i + 1,
            column: j,
            candidate: current,
            decision: const _Decision.skipExpected(),
          );
        }

        if (j < tapEvents.length) {
          _updateState(
            dp: dp,
            decisions: decisions,
            row: i,
            column: j + 1,
            candidate: current,
            decision: const _Decision.skipTap(),
          );
        }

        if (i < expectedEvents.length && j < tapEvents.length) {
          final errorSeconds =
              tapEvents[j].timeSeconds - expectedEvents[i].timeSeconds;
          final absoluteErrorSeconds = errorSeconds.abs();
          if (absoluteErrorSeconds <= matchingWindowSeconds) {
            _updateState(
              dp: dp,
              decisions: decisions,
              row: i + 1,
              column: j + 1,
              candidate: _MatchState(
                matchedCount: current.matchedCount + 1,
                totalAbsoluteErrorSeconds:
                    current.totalAbsoluteErrorSeconds + absoluteErrorSeconds,
                totalSquaredErrorSeconds:
                    current.totalSquaredErrorSeconds +
                    absoluteErrorSeconds * absoluteErrorSeconds,
              ),
              decision: _Decision.match(errorSeconds),
            );
          }
        }
      }
    }

    final matchedPairs = <MatchedRhythmPair>[];
    final unmatchedExpectedEvents = <ExpectedRhythmEvent>[];
    final unmatchedTapEvents = <TapInputEvent>[];

    var i = expectedEvents.length;
    var j = tapEvents.length;
    while (i > 0 || j > 0) {
      final decision = decisions[i][j];
      if (decision == null) {
        if (i > 0) {
          unmatchedExpectedEvents.add(expectedEvents[i - 1]);
          i -= 1;
          continue;
        }
        unmatchedTapEvents.add(tapEvents[j - 1]);
        j -= 1;
        continue;
      }

      switch (decision.kind) {
        case _DecisionKind.match:
          matchedPairs.add(
            MatchedRhythmPair(
              expected: expectedEvents[i - 1],
              tap: tapEvents[j - 1],
              errorSeconds: decision.errorSeconds!,
            ),
          );
          i -= 1;
          j -= 1;
        case _DecisionKind.skipExpected:
          unmatchedExpectedEvents.add(expectedEvents[i - 1]);
          i -= 1;
        case _DecisionKind.skipTap:
          unmatchedTapEvents.add(tapEvents[j - 1]);
          j -= 1;
      }
    }

    return RhythmTestResult(
      matchedPairs: matchedPairs.reversed.toList(growable: false),
      unmatchedExpectedEvents: unmatchedExpectedEvents.reversed.toList(
        growable: false,
      ),
      unmatchedTapEvents: unmatchedTapEvents.reversed.toList(growable: false),
      matchingWindowSeconds: matchingWindowSeconds,
      appliedShiftSeconds: 0,
    );
  }

  void _updateState({
    required List<List<_MatchState?>> dp,
    required List<List<_Decision?>> decisions,
    required int row,
    required int column,
    required _MatchState candidate,
    required _Decision decision,
  }) {
    final existing = dp[row][column];
    if (existing == null || candidate.isBetterThan(existing)) {
      dp[row][column] = candidate;
      decisions[row][column] = decision;
    }
  }
}

class _MatchState {
  final int matchedCount;
  final double totalAbsoluteErrorSeconds;
  final double totalSquaredErrorSeconds;

  const _MatchState({
    required this.matchedCount,
    required this.totalAbsoluteErrorSeconds,
    required this.totalSquaredErrorSeconds,
  });

  bool isBetterThan(_MatchState other) {
    if (matchedCount != other.matchedCount) {
      return matchedCount > other.matchedCount;
    }
    if ((totalAbsoluteErrorSeconds - other.totalAbsoluteErrorSeconds).abs() >
        RhythmMatcher._comparisonTolerance) {
      return totalAbsoluteErrorSeconds < other.totalAbsoluteErrorSeconds;
    }
    if ((totalSquaredErrorSeconds - other.totalSquaredErrorSeconds).abs() >
        RhythmMatcher._comparisonTolerance) {
      return totalSquaredErrorSeconds < other.totalSquaredErrorSeconds;
    }
    return false;
  }
}

enum _DecisionKind { match, skipExpected, skipTap }

class _Decision {
  final _DecisionKind kind;
  final double? errorSeconds;

  const _Decision._(this.kind, [this.errorSeconds]);

  const _Decision.match(double errorSeconds)
    : this._(_DecisionKind.match, errorSeconds);

  const _Decision.skipExpected() : this._(_DecisionKind.skipExpected);

  const _Decision.skipTap() : this._(_DecisionKind.skipTap);
}
