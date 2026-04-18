import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/rhythm_test/rhythm_matcher.dart';
import 'package:tap_score/rhythm_test/rhythm_test_models.dart';
import 'package:tap_score/rhythm_test/rhythm_timeline_builder.dart';
import 'package:tap_score/services/audio_service.dart';
import 'package:tap_score/state/rhythm_test_notifier.dart';

void main() {
  test(
    'count-in playhead advances continuously before the next pulse and stop resets it',
    () async {
      final notifier = RhythmTestNotifier(
        score: Score(
          bpm: 120,
          notes: [const Note(midi: 60, duration: NoteDuration.quarter)],
        ),
        audioService: _FakeAudioService(),
        timelineBuilder: _FixedTimelineBuilder(
          const RhythmTimeline(
            expectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
              ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.1),
            ],
            playbackNotes: [
              RhythmMelodyEvent(
                noteIndex: 0,
                midi: 60,
                startSeconds: 0,
                durationSeconds: 0.1,
              ),
            ],
            measureBoundaryTimesSeconds: [0, 0.2],
            totalDurationSeconds: 0.2,
            pulseDurationSeconds: 0.1,
            pulsesPerMeasure: 4,
          ),
        ),
      );

      addTearDown(notifier.dispose);

      await notifier.start();

      expect(notifier.phase, RhythmTestPhase.countIn);
      expect(notifier.playheadTimeSeconds, closeTo(-0.4, 0.03));

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final firstPlayhead = notifier.playheadTimeSeconds;
      final firstPulseIndex = notifier.countInPulseIndex;

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final secondPlayhead = notifier.playheadTimeSeconds;

      expect(firstPulseIndex, 0);
      expect(notifier.countInPulseIndex, firstPulseIndex);
      expect(firstPlayhead, greaterThan(-0.4));
      expect(firstPlayhead, lessThan(0));
      expect(secondPlayhead, greaterThan(firstPlayhead));
      expect(secondPlayhead, lessThan(0));

      notifier.stop();

      expect(notifier.playheadTimeSeconds, 0);
      expect(notifier.elapsedRunSeconds, 0);
    },
  );

  test(
    'count-in tap keeps negative time and overlay payload exposes lead-in timing',
    () async {
      final notifier = RhythmTestNotifier(
        score: Score(
          bpm: 120,
          notes: [const Note(midi: 60, duration: NoteDuration.quarter)],
        ),
        audioService: _FakeAudioService(),
        timelineBuilder: _FixedTimelineBuilder(
          const RhythmTimeline(
            expectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ],
            playbackNotes: [
              RhythmMelodyEvent(
                noteIndex: 0,
                midi: 60,
                startSeconds: 0,
                durationSeconds: 0.2,
              ),
            ],
            measureBoundaryTimesSeconds: [0, 0.2],
            totalDurationSeconds: 0.2,
            pulseDurationSeconds: 0.1,
            pulsesPerMeasure: 4,
          ),
        ),
      );

      addTearDown(notifier.dispose);

      await notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      notifier.recordTap();

      expect(notifier.tapEvents, hasLength(1));
      expect(notifier.tapEvents.single.timeSeconds, lessThan(0));
      expect(notifier.overlayRenderData.phase, RhythmOverlayRenderPhase.live);
      expect(
        notifier.overlayRenderData.countInDurationSeconds,
        closeTo(0.4, 0.0001),
      );
      expect(notifier.overlayRenderData.playheadTimeSeconds, lessThan(0));
    },
  );

  test('count-in plays metronome and running plays melody only', () async {
    final audioService = _FakeAudioService();
    final notifier = RhythmTestNotifier(
      score: Score(
        bpm: 120,
        notes: const [
          Note(midi: 60, duration: NoteDuration.quarter),
          Note(midi: 62, duration: NoteDuration.quarter),
        ],
      ),
      audioService: audioService,
      timelineBuilder: _FixedTimelineBuilder(
        const RhythmTimeline(
          expectedEvents: [
            ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.1),
          ],
          playbackNotes: [
            RhythmMelodyEvent(
              noteIndex: 0,
              midi: 60,
              startSeconds: 0,
              durationSeconds: 0.1,
            ),
            RhythmMelodyEvent(
              noteIndex: 1,
              midi: 62,
              startSeconds: 0.1,
              durationSeconds: 0.1,
            ),
          ],
          measureBoundaryTimesSeconds: [0, 0.2],
          totalDurationSeconds: 0.2,
          pulseDurationSeconds: 0.1,
          pulsesPerMeasure: 4,
        ),
      ),
    );

    addTearDown(notifier.dispose);

    await notifier.start();
    await Future<void>.delayed(const Duration(milliseconds: 760));

    expect(audioService.events, [
      'metro-accent',
      'metro-regular',
      'metro-regular',
      'metro-regular',
      'start-60',
      'stop-60',
      'start-62',
      'stop-62',
    ]);
  });

  test('init preloads rhythm test notes before a session starts', () async {
    final audioService = _FakeAudioService();
    final notifier = RhythmTestNotifier(
      score: Score(
        bpm: 120,
        notes: const [
          Note(midi: 60, duration: NoteDuration.quarter),
          Note(midi: 62, duration: NoteDuration.quarter),
        ],
      ),
      audioService: audioService,
      timelineBuilder: _FixedTimelineBuilder(
        const RhythmTimeline(
          expectedEvents: [
            ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.1),
          ],
          playbackNotes: [
            RhythmMelodyEvent(
              noteIndex: 0,
              midi: 60,
              startSeconds: 0,
              durationSeconds: 0.1,
            ),
            RhythmMelodyEvent(
              noteIndex: 1,
              midi: 62,
              startSeconds: 0.1,
              durationSeconds: 0.1,
            ),
          ],
          measureBoundaryTimesSeconds: [0, 0.2],
          totalDurationSeconds: 0.2,
          pulseDurationSeconds: 0.1,
          pulsesPerMeasure: 4,
        ),
      ),
    );

    addTearDown(notifier.dispose);

    await notifier.init();

    expect(audioService.preloadRequests, [
      [60, 62],
    ]);
  });

  test('running retriggers repeated same-pitch notes in order', () async {
    final audioService = _FakeAudioService();
    final notifier = RhythmTestNotifier(
      score: Score(
        bpm: 120,
        notes: const [
          Note(midi: 60, duration: NoteDuration.quarter),
          Note(midi: 60, duration: NoteDuration.quarter),
        ],
      ),
      audioService: audioService,
      timelineBuilder: _FixedTimelineBuilder(
        const RhythmTimeline(
          expectedEvents: [
            ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.1),
          ],
          playbackNotes: [
            RhythmMelodyEvent(
              noteIndex: 0,
              midi: 60,
              startSeconds: 0,
              durationSeconds: 0.1,
            ),
            RhythmMelodyEvent(
              noteIndex: 1,
              midi: 60,
              startSeconds: 0.1,
              durationSeconds: 0.1,
            ),
          ],
          measureBoundaryTimesSeconds: [0, 0.2],
          totalDurationSeconds: 0.2,
          pulseDurationSeconds: 0.1,
          pulsesPerMeasure: 4,
        ),
      ),
    );

    addTearDown(notifier.dispose);

    await notifier.start();
    await Future<void>.delayed(const Duration(milliseconds: 760));

    expect(audioService.events, [
      'metro-accent',
      'metro-regular',
      'metro-regular',
      'metro-regular',
      'start-60',
      'stop-60',
      'start-60',
      'stop-60',
    ]);
  });

  test('finished result locks restart before returning to Start', () async {
    final notifier = RhythmTestNotifier(
      score: Score(
        bpm: 120,
        notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
      ),
      audioService: _FakeAudioService(),
      timelineBuilder: _FixedTimelineBuilder(
        const RhythmTimeline(
          expectedEvents: [
            ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
          ],
          playbackNotes: [
            RhythmMelodyEvent(
              noteIndex: 0,
              midi: 60,
              startSeconds: 0,
              durationSeconds: 0.2,
            ),
          ],
          measureBoundaryTimesSeconds: [0, 0.2],
          totalDurationSeconds: 0.2,
          pulseDurationSeconds: 0.1,
          pulsesPerMeasure: 4,
        ),
      ),
    );

    addTearDown(notifier.dispose);

    await notifier.start();
    await Future<void>.delayed(const Duration(milliseconds: 820));

    expect(notifier.phase, RhythmTestPhase.finished);
    expect(notifier.restartLocked, isTrue);
    expect(notifier.canStart, isFalse);
    expect(notifier.primaryActionLabel, 'Start');
    expect(notifier.primaryActionHint, 'Space');

    final tapsBefore = notifier.tapEvents.length;
    notifier.recordTap();
    expect(notifier.tapEvents.length, tapsBefore);

    await Future<void>.delayed(
      RhythmTestNotifier.resultRevealLockDuration +
          const Duration(milliseconds: 140),
    );

    expect(notifier.restartLocked, isFalse);
    expect(notifier.canStart, isTrue);
  });

  test(
    'finished enters scoring state before result becomes available',
    () async {
      final scoringGate = Completer<void>();
      final notifier = RhythmTestNotifier(
        score: Score(
          bpm: 120,
          notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
        ),
        audioService: _FakeAudioService(),
        timelineBuilder: _FixedTimelineBuilder(
          const RhythmTimeline(
            expectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ],
            playbackNotes: [
              RhythmMelodyEvent(
                noteIndex: 0,
                midi: 60,
                startSeconds: 0,
                durationSeconds: 0.2,
              ),
            ],
            measureBoundaryTimesSeconds: [0, 0.2],
            totalDurationSeconds: 0.2,
            pulseDurationSeconds: 0.1,
            pulsesPerMeasure: 4,
          ),
        ),
        matcher: _FixedMatcher(
          const RhythmTestResult(
            matchedPairs: [],
            unmatchedExpectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ],
            unmatchedTapEvents: [],
            matchingWindowSeconds: 0.1,
            appliedShiftSeconds: 0,
          ),
        ),
        waitBeforeScoring: () => scoringGate.future,
      );

      addTearDown(notifier.dispose);

      await notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 860));

      expect(notifier.phase, RhythmTestPhase.finished);
      expect(notifier.isScoringResult, isTrue);
      expect(notifier.result, isNull);
      expect(notifier.showCenteredResult, isTrue);
      expect(notifier.restartLocked, isTrue);
      expect(
        notifier.overlayRenderData.phase,
        RhythmOverlayRenderPhase.pendingResult,
      );

      scoringGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.isScoringResult, isFalse);
      expect(notifier.result, isNotNull);
      expect(notifier.restartLocked, isTrue);
    },
  );

  test('stop during scoring discards the stale result', () async {
    final scoringGate = Completer<void>();
    final notifier = RhythmTestNotifier(
      score: Score(
        bpm: 120,
        notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
      ),
      audioService: _FakeAudioService(),
      timelineBuilder: _FixedTimelineBuilder(
        const RhythmTimeline(
          expectedEvents: [
            ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
          ],
          playbackNotes: [
            RhythmMelodyEvent(
              noteIndex: 0,
              midi: 60,
              startSeconds: 0,
              durationSeconds: 0.2,
            ),
          ],
          measureBoundaryTimesSeconds: [0, 0.2],
          totalDurationSeconds: 0.2,
          pulseDurationSeconds: 0.1,
          pulsesPerMeasure: 4,
        ),
      ),
      matcher: _FixedMatcher(
        const RhythmTestResult(
          matchedPairs: [],
          unmatchedExpectedEvents: [
            ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
          ],
          unmatchedTapEvents: [],
          matchingWindowSeconds: 0.1,
          appliedShiftSeconds: 0,
        ),
      ),
      waitBeforeScoring: () => scoringGate.future,
    );

    addTearDown(notifier.dispose);

    await notifier.start();
    await Future<void>.delayed(const Duration(milliseconds: 820));

    expect(notifier.isScoringResult, isTrue);

    notifier.stop();
    scoringGate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(notifier.phase, RhythmTestPhase.idle);
    expect(notifier.isScoringResult, isFalse);
    expect(notifier.result, isNull);
    expect(notifier.showCenteredResult, isFalse);
    expect(notifier.overlayRenderData.phase, RhythmOverlayRenderPhase.idle);
  });

  test(
    'result getters and overlay payload expose error-focused metrics',
    () async {
      final notifier = RhythmTestNotifier(
        score: Score(
          bpm: 120,
          notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
        ),
        audioService: _FakeAudioService(),
        timelineBuilder: _FixedTimelineBuilder(
          const RhythmTimeline(
            expectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ],
            playbackNotes: [
              RhythmMelodyEvent(
                noteIndex: 0,
                midi: 60,
                startSeconds: 0,
                durationSeconds: 0.2,
              ),
            ],
            measureBoundaryTimesSeconds: [0, 0.2],
            totalDurationSeconds: 0.2,
            pulseDurationSeconds: 0.1,
            pulsesPerMeasure: 4,
          ),
        ),
      );

      addTearDown(notifier.dispose);

      await notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 860));

      expect(notifier.resultErrorCount, 1);
      expect(notifier.resultErrorCountLabel, '1');
      expect(notifier.resultLargeErrorCount, 0);
      expect(notifier.resultAverageErrorBeats, isNull);
      expect(notifier.resultMaxErrorBeats, isNull);
      expect(notifier.resultStatusLabel, 'Failed');
      expect(notifier.resultSummaryLabel, contains('BPM 120'));
      expect(notifier.largeOffsetThresholdLabel, '0.10 beat');
      expect(notifier.suggestedRetryBpm, 102);
      expect(
        notifier.resultRecommendationLabel,
        'Retry slower at 102 BPM and tap only note starts.',
      );
      expect(notifier.overlayRenderData.phase, RhythmOverlayRenderPhase.result);
      expect(notifier.overlayRenderData.errorLabelThresholdBeats, 0.05);
      expect(notifier.overlayRenderData.largeErrorThresholdBeats, 0.1);
      expect(notifier.overlayRenderData.missedExpectedNoteIndices, [0]);
    },
  );

  test(
    'overlay phase stays pending until scoring data exists, then switches to result',
    () async {
      final scoringGate = Completer<void>();
      final notifier = RhythmTestNotifier(
        score: Score(
          bpm: 120,
          notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
        ),
        audioService: _FakeAudioService(),
        timelineBuilder: _FixedTimelineBuilder(
          const RhythmTimeline(
            expectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ],
            playbackNotes: [
              RhythmMelodyEvent(
                noteIndex: 0,
                midi: 60,
                startSeconds: 0,
                durationSeconds: 0.2,
              ),
            ],
            measureBoundaryTimesSeconds: [0, 0.2],
            totalDurationSeconds: 0.2,
            pulseDurationSeconds: 0.1,
            pulsesPerMeasure: 4,
          ),
        ),
        matcher: _FixedMatcher(
          const RhythmTestResult(
            matchedPairs: [
              MatchedRhythmPair(
                expected: ExpectedRhythmEvent(
                  id: 1,
                  noteIndex: 0,
                  timeSeconds: 0,
                ),
                tap: TapInputEvent(id: 1, timeSeconds: 0.31),
                errorSeconds: 0.11,
              ),
            ],
            unmatchedExpectedEvents: [],
            unmatchedTapEvents: [TapInputEvent(id: 2, timeSeconds: 0.56)],
            matchingWindowSeconds: 0.1,
            appliedShiftSeconds: 0.2,
          ),
        ),
        waitBeforeScoring: () => scoringGate.future,
      );

      addTearDown(notifier.dispose);

      await notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      notifier.recordTap();
      await Future<void>.delayed(const Duration(milliseconds: 830));

      expect(notifier.phase, RhythmTestPhase.finished);
      expect(notifier.result, isNull);
      expect(
        notifier.overlayRenderData.phase,
        RhythmOverlayRenderPhase.pendingResult,
      );
      expect(notifier.overlayRenderData.liveTapEvents, hasLength(1));
      expect(notifier.overlayRenderData.resultTapEvents, isEmpty);

      scoringGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(notifier.result, isNotNull);
      expect(notifier.overlayRenderData.phase, RhythmOverlayRenderPhase.result);
      expect(
        notifier.overlayRenderData.resultTapEvents.map(
          (tap) => tap.timeSeconds,
        ),
        orderedEquals([closeTo(0.11, 0.0001), closeTo(0.36, 0.0001)]),
      );
      expect(
        (notifier.overlayRenderData.toPayload()['resultTapEvents'] as List).map(
          (tap) => (tap as Map<String, dynamic>)['timeSeconds'],
        ),
        orderedEquals([closeTo(0.11, 0.0001), closeTo(0.36, 0.0001)]),
      );
      expect(notifier.resultShiftLabel, '+2.00 beat');
    },
  );

  test(
    'large error threshold is adjustable at runtime and updates result status',
    () async {
      final notifier = RhythmTestNotifier(
        score: Score(
          bpm: 120,
          notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
        ),
        audioService: _FakeAudioService(),
        timelineBuilder: _FixedTimelineBuilder(
          const RhythmTimeline(
            expectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ],
            playbackNotes: [
              RhythmMelodyEvent(
                noteIndex: 0,
                midi: 60,
                startSeconds: 0,
                durationSeconds: 0.2,
              ),
            ],
            measureBoundaryTimesSeconds: [0, 0.2],
            totalDurationSeconds: 0.2,
            pulseDurationSeconds: 0.1,
            pulsesPerMeasure: 4,
          ),
        ),
        matcher: _FixedMatcher(
          const RhythmTestResult(
            matchedPairs: [
              MatchedRhythmPair(
                expected: ExpectedRhythmEvent(
                  id: 1,
                  noteIndex: 0,
                  timeSeconds: 0,
                ),
                tap: TapInputEvent(id: 1, timeSeconds: 0.012),
                errorSeconds: 0.012,
              ),
            ],
            unmatchedExpectedEvents: [],
            unmatchedTapEvents: [],
            matchingWindowSeconds: 0.1,
            appliedShiftSeconds: 0,
          ),
        ),
      );

      addTearDown(notifier.dispose);

      await notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 820));

      expect(notifier.resultLargeErrorCount, 1);
      expect(notifier.resultStatusLabel, 'Clean, but loose');
      expect(notifier.resultMaxErrorBeats, closeTo(0.12, 0.001));
      expect(
        notifier.resultRecommendationLabel,
        'Keep BPM and tighten alignment.',
      );
      expect(notifier.overlayRenderData.largeErrorThresholdBeats, 0.1);

      notifier.setLargeErrorThreshold(0.15);

      expect(notifier.largeErrorThresholdBeats, 0.15);
      expect(notifier.resultLargeErrorCount, 0);
      expect(notifier.resultStatusLabel, 'Perfect');
      expect(
        notifier.resultRecommendationLabel,
        'Raise BPM by 5–10 and retry.',
      );
      expect(notifier.overlayRenderData.largeErrorThresholdBeats, 0.15);
    },
  );

  test(
    'clean but loose recommendation identifies consistent late taps',
    () async {
      final notifier = RhythmTestNotifier(
        score: Score(
          bpm: 120,
          notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
        ),
        audioService: _FakeAudioService(),
        timelineBuilder: _FixedTimelineBuilder(
          const RhythmTimeline(
            expectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ],
            playbackNotes: [
              RhythmMelodyEvent(
                noteIndex: 0,
                midi: 60,
                startSeconds: 0,
                durationSeconds: 0.2,
              ),
            ],
            measureBoundaryTimesSeconds: [0, 0.2],
            totalDurationSeconds: 0.2,
            pulseDurationSeconds: 0.1,
            pulsesPerMeasure: 4,
          ),
        ),
        matcher: _FixedMatcher(
          const RhythmTestResult(
            matchedPairs: [
              MatchedRhythmPair(
                expected: ExpectedRhythmEvent(
                  id: 1,
                  noteIndex: 0,
                  timeSeconds: 0,
                ),
                tap: TapInputEvent(id: 1, timeSeconds: 0.012),
                errorSeconds: 0.012,
              ),
            ],
            unmatchedExpectedEvents: [],
            unmatchedTapEvents: [],
            matchingWindowSeconds: 0.1,
            appliedShiftSeconds: 0.006,
          ),
        ),
      );

      addTearDown(notifier.dispose);

      await notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 820));

      expect(notifier.resultStatusLabel, 'Clean, but loose');
      expect(notifier.resultShiftBeats, closeTo(0.06, 0.001));
      expect(
        notifier.resultRecommendationLabel,
        "You're consistently late. Keep BPM and tap slightly earlier.",
      );
    },
  );

  test(
    'count-in progress notifications stay below the live loop cadence',
    () async {
      final notifier = RhythmTestNotifier(
        score: Score(
          bpm: 120,
          notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
        ),
        audioService: _FakeAudioService(),
        timelineBuilder: _FixedTimelineBuilder(
          const RhythmTimeline(
            expectedEvents: [
              ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ],
            playbackNotes: [
              RhythmMelodyEvent(
                noteIndex: 0,
                midi: 60,
                startSeconds: 0,
                durationSeconds: 0.2,
              ),
            ],
            measureBoundaryTimesSeconds: [0, 0.2],
            totalDurationSeconds: 0.2,
            pulseDurationSeconds: 0.5,
            pulsesPerMeasure: 4,
          ),
        ),
      );

      addTearDown(notifier.dispose);
      await notifier.init();

      var notifications = 0;
      void listener() {
        notifications += 1;
      }

      notifier.addListener(listener);
      await notifier.start();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      notifier.removeListener(listener);
      notifier.stop();

      expect(notifications, lessThanOrEqualTo(4));
    },
  );
}

class _FixedTimelineBuilder extends RhythmTimelineBuilder {
  const _FixedTimelineBuilder(this.timeline);

  final RhythmTimeline timeline;

  @override
  RhythmTimeline build(Score score) => timeline;
}

class _FixedMatcher extends RhythmMatcher {
  const _FixedMatcher(this.result);

  final RhythmTestResult result;

  @override
  RhythmTestResult match({
    required List<ExpectedRhythmEvent> expectedEvents,
    required List<TapInputEvent> tapEvents,
    required double matchingWindowSeconds,
  }) => result;
}

class _FakeAudioService extends AudioService {
  final List<String> events = [];
  final List<List<int>> preloadRequests = [];
  int _nextHandleId = 1;

  @override
  Future<bool> init() async => true;

  @override
  Future<void> preloadRhythmTestNotes(Iterable<int> melodyMidis) async {
    preloadRequests.add(melodyMidis.toList(growable: false));
  }

  @override
  Future<AudioNoteHandle?> startNote(
    int midi, {
    int velocity = AudioService.defaultPlaybackVelocity,
  }) async {
    events.add('start-$midi');
    return AudioNoteHandle(id: _nextHandleId++, midi: midi);
  }

  @override
  Future<void> stopNoteHandle(AudioNoteHandle handle) async {
    events.add('stop-${handle.midi}');
  }

  @override
  void playRhythmTestMetronomeClick({required bool accented}) {
    events.add(accented ? 'metro-accent' : 'metro-regular');
  }

  @override
  void stopPlayback() {}

  @override
  void dispose() {}
}
