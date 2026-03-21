class ExpectedRhythmEvent {
  final int id;
  final int noteIndex;
  final double timeSeconds;

  const ExpectedRhythmEvent({
    required this.id,
    required this.noteIndex,
    required this.timeSeconds,
  });
}

class TapInputEvent {
  final int id;
  final double timeSeconds;

  const TapInputEvent({required this.id, required this.timeSeconds});
}

class MatchedRhythmPair {
  final ExpectedRhythmEvent expected;
  final TapInputEvent tap;
  final double errorSeconds;

  const MatchedRhythmPair({
    required this.expected,
    required this.tap,
    required this.errorSeconds,
  });

  double get absoluteErrorSeconds => errorSeconds.abs();
}

class RhythmTimeline {
  final List<ExpectedRhythmEvent> expectedEvents;
  final List<double> measureBoundaryTimesSeconds;
  final double totalDurationSeconds;
  final double pulseDurationSeconds;
  final int pulsesPerMeasure;

  const RhythmTimeline({
    required this.expectedEvents,
    required this.measureBoundaryTimesSeconds,
    required this.totalDurationSeconds,
    required this.pulseDurationSeconds,
    required this.pulsesPerMeasure,
  });

  int get countInPulseCount => pulsesPerMeasure;

  double get countInDurationSeconds => countInPulseCount * pulseDurationSeconds;

  double get matchingWindowSeconds => pulseDurationSeconds;
}

class RhythmTestResult {
  final List<MatchedRhythmPair> matchedPairs;
  final List<ExpectedRhythmEvent> unmatchedExpectedEvents;
  final List<TapInputEvent> unmatchedTapEvents;
  final double matchingWindowSeconds;
  final double appliedShiftSeconds;

  const RhythmTestResult({
    required this.matchedPairs,
    required this.unmatchedExpectedEvents,
    required this.unmatchedTapEvents,
    required this.matchingWindowSeconds,
    required this.appliedShiftSeconds,
  });

  int get expectedCount => matchedPairs.length + unmatchedExpectedEvents.length;

  int get matchedCount => matchedPairs.length;

  double get totalAbsoluteErrorSeconds => matchedPairs.fold<double>(
    0,
    (sum, pair) => sum + pair.absoluteErrorSeconds,
  );

  double? get averageAbsoluteErrorSeconds {
    return shiftedAverageAbsoluteErrorSeconds;
  }

  double? get shiftedAverageAbsoluteErrorSeconds {
    if (matchedPairs.isEmpty) {
      return null;
    }

    return totalAbsoluteErrorSeconds / matchedPairs.length;
  }
}

class RhythmOverlayRenderData {
  final bool showExpectedEvents;
  final double elapsedRunSeconds;
  final double playheadTimeSeconds;
  final double countInDurationSeconds;
  final double totalDurationSeconds;
  final double pulseDurationSeconds;
  final int pulsesPerMeasure;
  final List<double> measureBoundaryTimesSeconds;
  final List<ExpectedRhythmEvent> expectedEvents;
  final List<TapInputEvent> liveTapEvents;
  final List<TapInputEvent> resultTapEvents;
  final List<MatchedRhythmPair> matchedPairs;
  final double appliedShiftSeconds;

  const RhythmOverlayRenderData({
    required this.showExpectedEvents,
    required this.elapsedRunSeconds,
    required this.playheadTimeSeconds,
    required this.countInDurationSeconds,
    required this.totalDurationSeconds,
    required this.pulseDurationSeconds,
    required this.pulsesPerMeasure,
    required this.measureBoundaryTimesSeconds,
    required this.expectedEvents,
    required this.liveTapEvents,
    required this.resultTapEvents,
    required this.matchedPairs,
    required this.appliedShiftSeconds,
  });

  Map<String, dynamic> toPayload() {
    return {
      'showExpectedEvents': showExpectedEvents,
      'elapsedRunSeconds': elapsedRunSeconds,
      'playheadTimeSeconds': playheadTimeSeconds,
      'countInDurationSeconds': countInDurationSeconds,
      'totalDurationSeconds': totalDurationSeconds,
      'pulseDurationSeconds': pulseDurationSeconds,
      'pulsesPerMeasure': pulsesPerMeasure,
      'measureBoundaryTimesSeconds': measureBoundaryTimesSeconds,
      'expectedEvents': expectedEvents
          .map((event) => {'id': event.id, 'timeSeconds': event.timeSeconds})
          .toList(growable: false),
      'liveTapEvents': liveTapEvents
          .map((tap) => {'id': tap.id, 'timeSeconds': tap.timeSeconds})
          .toList(growable: false),
      'resultTapEvents': resultTapEvents
          .map((tap) => {'id': tap.id, 'timeSeconds': tap.timeSeconds})
          .toList(growable: false),
      'matchedPairs': matchedPairs
          .map(
            (pair) => {
              'expectedId': pair.expected.id,
              'tapId': pair.tap.id,
              'errorSeconds': pair.errorSeconds,
            },
          )
          .toList(growable: false),
      'appliedShiftSeconds': appliedShiftSeconds,
    };
  }
}
