import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
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
      expect(
        notifier.overlayRenderData.countInDurationSeconds,
        closeTo(0.4, 0.0001),
      );
      expect(notifier.overlayRenderData.playheadTimeSeconds, lessThan(0));
    },
  );
}

class _FixedTimelineBuilder extends RhythmTimelineBuilder {
  const _FixedTimelineBuilder(this.timeline);

  final RhythmTimeline timeline;

  @override
  RhythmTimeline build(Score score) => timeline;
}

class _FakeAudioService extends AudioService {
  @override
  Future<bool> init() async => true;

  @override
  void playMetronomeClick({required bool accented}) {}

  @override
  void dispose() {}
}
