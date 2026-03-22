import '../services/playback_schedule.dart';

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

class RhythmTestDisplayConfig {
  static const double defaultErrorLabelThresholdBeats = 0.05;
  static const double defaultLargeErrorThresholdBeats = 0.1;

  final double errorLabelThresholdBeats;
  final double largeErrorThresholdBeats;

  const RhythmTestDisplayConfig({
    this.errorLabelThresholdBeats = defaultErrorLabelThresholdBeats,
    this.largeErrorThresholdBeats = defaultLargeErrorThresholdBeats,
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
  final List<ScheduledPlaybackNote> playbackNotes;
  final List<double> measureBoundaryTimesSeconds;
  final double totalDurationSeconds;
  final double pulseDurationSeconds;
  final int pulsesPerMeasure;

  const RhythmTimeline({
    required this.expectedEvents,
    required this.playbackNotes,
    required this.measureBoundaryTimesSeconds,
    required this.totalDurationSeconds,
    required this.pulseDurationSeconds,
    required this.pulsesPerMeasure,
  });

  int get countInPulseCount => pulsesPerMeasure;

  double get countInDurationSeconds => countInPulseCount * pulseDurationSeconds;

  double get matchingWindowSeconds => pulseDurationSeconds;
}

typedef RhythmMelodyEvent = ScheduledPlaybackNote;

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

  int get errorCount =>
      unmatchedExpectedEvents.length + unmatchedTapEvents.length;

  List<int> get missedExpectedNoteIndices => unmatchedExpectedEvents
      .map((event) => event.noteIndex)
      .toList(growable: false);

  double get totalAbsoluteErrorSeconds => matchedPairs.fold<double>(
    0,
    (sum, pair) => sum + pair.absoluteErrorSeconds,
  );

  double? get maxAbsoluteErrorSeconds {
    if (matchedPairs.isEmpty) {
      return null;
    }
    return matchedPairs
        .map((pair) => pair.absoluteErrorSeconds)
        .reduce((left, right) => left > right ? left : right);
  }

  double? get averageAbsoluteErrorSeconds {
    return shiftedAverageAbsoluteErrorSeconds;
  }

  double? get shiftedAverageAbsoluteErrorSeconds {
    if (matchedPairs.isEmpty) {
      return null;
    }

    return totalAbsoluteErrorSeconds / matchedPairs.length;
  }

  int largeErrorCountForThreshold(double thresholdSeconds) {
    return largeErrorExpectedNoteIndicesForThreshold(thresholdSeconds).length;
  }

  List<int> largeErrorExpectedNoteIndicesForThreshold(double thresholdSeconds) {
    return matchedPairs
        .where((pair) => pair.absoluteErrorSeconds > thresholdSeconds)
        .map((pair) => pair.expected.noteIndex)
        .toList(growable: false);
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
  final double errorLabelThresholdBeats;
  final double largeErrorThresholdBeats;
  final List<int> largeErrorNoteIndices;
  final List<int> missedExpectedNoteIndices;

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
    required this.errorLabelThresholdBeats,
    required this.largeErrorThresholdBeats,
    required this.largeErrorNoteIndices,
    required this.missedExpectedNoteIndices,
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
      'errorLabelThresholdBeats': errorLabelThresholdBeats,
      'largeErrorThresholdBeats': largeErrorThresholdBeats,
      'largeErrorNoteIndices': largeErrorNoteIndices,
      'missedExpectedNoteIndices': missedExpectedNoteIndices,
    };
  }
}
