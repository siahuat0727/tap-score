import 'rhythm_test_models.dart';

class RhythmMatcher {
  const RhythmMatcher();

  RhythmTestResult match({
    required List<ExpectedRhythmEvent> expectedEvents,
    required List<TapInputEvent> tapEvents,
    required double matchingWindowSeconds,
  }) {
    if (expectedEvents.isEmpty || tapEvents.isEmpty) {
      return _matchOrdered(
        expectedEvents: expectedEvents,
        tapEvents: tapEvents,
        matchingWindowSeconds: matchingWindowSeconds,
        appliedShiftSeconds: 0,
      );
    }

    final baselineResult = _matchOrdered(
      expectedEvents: expectedEvents,
      tapEvents: tapEvents,
      matchingWindowSeconds: matchingWindowSeconds,
      appliedShiftSeconds: 0,
    );
    if (baselineResult.matchedCount < 2) {
      return baselineResult;
    }

    final appliedShiftSeconds = _estimateShiftSeconds(baselineResult);
    if (appliedShiftSeconds == 0) {
      return baselineResult;
    }

    final shiftedTapEvents = tapEvents
        .map(
          (tap) => TapInputEvent(
            id: tap.id,
            timeSeconds: tap.timeSeconds - appliedShiftSeconds,
          ),
        )
        .toList(growable: false);
    return _matchOrdered(
      expectedEvents: expectedEvents,
      tapEvents: shiftedTapEvents,
      matchingWindowSeconds: matchingWindowSeconds,
      appliedShiftSeconds: appliedShiftSeconds,
    );
  }

  RhythmTestResult _matchOrdered({
    required List<ExpectedRhythmEvent> expectedEvents,
    required List<TapInputEvent> tapEvents,
    required double matchingWindowSeconds,
    required double appliedShiftSeconds,
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

    dp[0][0] = const _MatchState(matchCount: 0, totalErrorSeconds: 0);

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
          if (errorSeconds.abs() <= matchingWindowSeconds) {
            _updateState(
              dp: dp,
              decisions: decisions,
              row: i + 1,
              column: j + 1,
              candidate: _MatchState(
                matchCount: current.matchCount + 1,
                totalErrorSeconds:
                    current.totalErrorSeconds + errorSeconds.abs(),
              ),
              decision: _Decision.match(errorSeconds),
            );
          }
        }
      }
    }

    final matchedPairs = <MatchedRhythmPair>[];
    final unmatchedExpected = <ExpectedRhythmEvent>[];
    final unmatchedTaps = <TapInputEvent>[];

    var i = expectedEvents.length;
    var j = tapEvents.length;
    while (i > 0 || j > 0) {
      final decision = decisions[i][j];
      if (decision == null) {
        if (i > 0) {
          unmatchedExpected.add(expectedEvents[i - 1]);
          i -= 1;
          continue;
        }
        unmatchedTaps.add(tapEvents[j - 1]);
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
          unmatchedExpected.add(expectedEvents[i - 1]);
          i -= 1;
        case _DecisionKind.skipTap:
          unmatchedTaps.add(tapEvents[j - 1]);
          j -= 1;
      }
    }

    return RhythmTestResult(
      matchedPairs: matchedPairs.reversed.toList(growable: false),
      unmatchedExpectedEvents: unmatchedExpected.reversed.toList(
        growable: false,
      ),
      unmatchedTapEvents: unmatchedTaps.reversed.toList(growable: false),
      matchingWindowSeconds: matchingWindowSeconds,
      appliedShiftSeconds: appliedShiftSeconds,
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

  double _estimateShiftSeconds(RhythmTestResult baselineResult) {
    final candidateErrors = baselineResult.matchedPairs.toList(
      growable: false,
    )..sort((a, b) => a.absoluteErrorSeconds.compareTo(b.absoluteErrorSeconds));
    final selectedCount = (candidateErrors.length / 2).ceil();
    final selectedErrors =
        candidateErrors
            .take(selectedCount)
            .map((pair) => pair.errorSeconds)
            .toList(growable: false)
          ..sort();

    if (selectedErrors.isEmpty) {
      return 0;
    }
    final middle = selectedErrors.length ~/ 2;
    if (selectedErrors.length.isOdd) {
      return selectedErrors[middle];
    }
    return (selectedErrors[middle - 1] + selectedErrors[middle]) / 2;
  }
}

class _MatchState {
  final int matchCount;
  final double totalErrorSeconds;

  const _MatchState({
    required this.matchCount,
    required this.totalErrorSeconds,
  });

  bool isBetterThan(_MatchState other) {
    if (matchCount != other.matchCount) {
      return matchCount > other.matchCount;
    }
    return totalErrorSeconds < other.totalErrorSeconds;
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
