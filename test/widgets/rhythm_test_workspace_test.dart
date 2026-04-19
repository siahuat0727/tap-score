import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/rhythm_test/rhythm_matcher.dart';
import 'package:tap_score/rhythm_test/rhythm_test_models.dart';
import 'package:tap_score/rhythm_test/rhythm_timeline_builder.dart';
import 'package:tap_score/services/audio_service.dart';
import 'package:tap_score/state/rhythm_test_notifier.dart';
import 'package:tap_score/state/score_notifier.dart';
import 'package:tap_score/widgets/rhythm_test_workspace.dart';
import 'package:tap_score/widgets/score_view_widget.dart';
import 'package:tap_score/workspace/workspace_layout_profile.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers/fake_webview_platform.dart';

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  testWidgets('workspace uses one primary control and no legacy buttons', (
    WidgetTester tester,
  ) async {
    final notifier = _buildNotifier();
    addTearDown(notifier.dispose);
    await notifier.init();

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump();

    expect(find.byKey(const ValueKey('rhythm-test-primary')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-start')), findsNothing);
    expect(find.byKey(const ValueKey('rhythm-test-reset')), findsNothing);
    expect(find.byKey(const ValueKey('rhythm-test-tap')), findsNothing);
    expect(find.text('Phase'), findsNothing);
    expect(find.text('Matched'), findsNothing);
    expect(find.text('Errors'), findsNothing);
    expect(find.byKey(const ValueKey('rhythm-test-tempo')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-threshold')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhythm-test-tempo-increment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rhythm-test-threshold-increment')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    final buttonRect = tester.getRect(
      find.byKey(const ValueKey('rhythm-test-primary')),
    );
    expect(buttonRect.width, greaterThan(300));
  });

  testWidgets('threshold increment button allows fine adjustment', (
    WidgetTester tester,
  ) async {
    final notifier = _buildNotifier();
    addTearDown(notifier.dispose);
    await notifier.init();

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('rhythm-test-threshold-increment')),
    );
    await tester.pump();

    expect(notifier.largeErrorThresholdBeats, closeTo(0.11, 0.0001));
  });

  testWidgets('phone layout stacks parameter cards without overflow', (
    WidgetTester tester,
  ) async {
    final notifier = _buildNotifier();
    addTearDown(notifier.dispose);
    await notifier.init();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(notifier, platform: TargetPlatform.android));
    await tester.pump();

    final tempoCard = tester.getRect(
      find.byKey(const ValueKey('rhythm-test-tempo')),
    );
    final thresholdCard = tester.getRect(
      find.byKey(const ValueKey('rhythm-test-threshold')),
    );

    expect(thresholdCard.top, greaterThan(tempoCard.bottom));
    expect(
      find.byKey(const ValueKey('rhythm-test-tempo-value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rhythm-test-threshold-value')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'primary button becomes Tap during play and result card appears',
    (WidgetTester tester) async {
      final notifier = _buildNotifier();
      addTearDown(notifier.dispose);
      await notifier.init();

      await tester.pumpWidget(_wrap(notifier, platform: TargetPlatform.macOS));
      await tester.pump();

      await tester.runAsync(() async {
        await notifier.performPrimaryAction();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();

      expect(find.textContaining('Tap'), findsOneWidget);
      expect(find.textContaining('Space'), findsOneWidget);
      expect(find.textContaining('Enter'), findsNothing);
      expect(
        tester
            .widget<ScoreViewWidget>(find.byType(ScoreViewWidget))
            .blockRendererPointerInput,
        isFalse,
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 900));
      });
      await tester.pump();

      expect(
        find.byKey(const ValueKey('rhythm-test-result-card')),
        findsOneWidget,
      );
      expect(find.text('Perfect'), findsNothing);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Mistakes'), findsOneWidget);
      expect(find.text('Max abs error'), findsOneWidget);
      expect(find.text('Large offsets'), findsOneWidget);
      expect(find.text('Matched'), findsNothing);
      expect(
        find.textContaining('Large-offset threshold 0.10 beat'),
        findsOneWidget,
      );
      expect(find.textContaining('Shift +0.00 beat'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('rhythm-test-result-recommendation')),
        findsOneWidget,
      );
      expect(
        find.text('Retry slower at 102 BPM and tap only note starts.'),
        findsOneWidget,
      );

      final workspaceRect = tester.getRect(find.byType(RhythmTestWorkspace));
      final resultRect = tester.getRect(
        find.byKey(const ValueKey('rhythm-test-result-card')),
      );
      expect(resultRect.center.dy, greaterThan(workspaceRect.height * 0.24));
      expect(
        tester
            .widget<ScoreViewWidget>(find.byType(ScoreViewWidget))
            .blockRendererPointerInput,
        isTrue,
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(
          RhythmTestNotifier.resultRevealLockDuration +
              const Duration(milliseconds: 80),
        );
      });
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('rhythm-test-result-card')),
        findsOneWidget,
      );
    },
  );

  testWidgets('primary action hides keyboard hint on touch-first profile', (
    WidgetTester tester,
  ) async {
    final notifier = _buildNotifier();
    addTearDown(notifier.dispose);
    await notifier.init();

    await tester.pumpWidget(_wrap(notifier, platform: TargetPlatform.android));
    await tester.pump();

    expect(find.textContaining('Space'), findsNothing);

    await tester.runAsync(() async {
      await notifier.performPrimaryAction();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.textContaining('Tap'), findsOneWidget);
    expect(find.textContaining('Space'), findsNothing);
  });

  testWidgets('stop button is visible during play and restores idle UI', (
    WidgetTester tester,
  ) async {
    final notifier = _buildNotifier();
    addTearDown(notifier.dispose);
    await notifier.init();

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump();

    await tester.runAsync(() async {
      await notifier.performPrimaryAction();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.byKey(const ValueKey('rhythm-test-stop')), findsOneWidget);
    expect(find.textContaining('Tap'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rhythm-test-stop')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(notifier.phase, RhythmTestPhase.idle);
    expect(notifier.tapEvents, isEmpty);
    expect(notifier.result, isNull);
    expect(find.byKey(const ValueKey('rhythm-test-stop')), findsNothing);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-result-card')), findsNothing);
    expect(
      tester
          .widget<ScoreViewWidget>(find.byType(ScoreViewWidget))
          .blockRendererPointerInput,
      isFalse,
    );
  });

  testWidgets('result summary can be closed without clearing rendered result', (
    WidgetTester tester,
  ) async {
    final notifier = _buildNotifier();
    addTearDown(notifier.dispose);
    await notifier.init();

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump();

    await tester.runAsync(() async {
      await notifier.performPrimaryAction();
      await Future<void>.delayed(const Duration(milliseconds: 900));
    });
    await tester.pump();

    expect(
      find.byKey(const ValueKey('rhythm-test-result-card')),
      findsOneWidget,
    );
    expect(notifier.result, isNotNull);
    expect(
      find.byKey(const ValueKey('rhythm-test-result-close')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ScoreViewWidget>(find.byType(ScoreViewWidget))
          .blockRendererPointerInput,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('rhythm-test-result-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.byKey(const ValueKey('rhythm-test-result-card')), findsNothing);
    expect(notifier.result, isNotNull);
    expect(
      tester
          .widget<ScoreViewWidget>(find.byType(ScoreViewWidget))
          .blockRendererPointerInput,
      isFalse,
    );
  });

  testWidgets('workspace shows loading card before the final result card', (
    WidgetTester tester,
  ) async {
    final scoringGate = Completer<void>();
    final notifier = _buildNotifier(
      matcher: _FixedMatcher(
        const RhythmTestResult(
          matchedPairs: [],
          unmatchedExpectedEvents: [
            ExpectedRhythmEvent(id: 1, noteIndex: 0, timeSeconds: 0),
            ExpectedRhythmEvent(id: 2, noteIndex: 1, timeSeconds: 0.1),
          ],
          unmatchedTapEvents: [],
          matchingWindowSeconds: 0.1,
          appliedShiftSeconds: 0,
        ),
      ),
      waitBeforeScoring: () => scoringGate.future,
    );
    addTearDown(notifier.dispose);
    await notifier.init();

    await tester.pumpWidget(_wrap(notifier));
    await tester.pump();

    await tester.runAsync(() async {
      await notifier.performPrimaryAction();
      await Future<void>.delayed(const Duration(milliseconds: 860));
    });
    await tester.pump();

    expect(
      find.byKey(const ValueKey('rhythm-test-result-card')),
      findsOneWidget,
    );
    expect(find.text('Calculating result…'), findsOneWidget);
    expect(find.text('Failed'), findsNothing);
    expect(
      tester
          .widget<ScoreViewWidget>(find.byType(ScoreViewWidget))
          .blockRendererPointerInput,
      isTrue,
    );

    scoringGate.complete();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.text('Calculating result…'), findsNothing);
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('result card shows clean but loose recommendation', (
    WidgetTester tester,
  ) async {
    final notifier = _buildNotifier(
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
            MatchedRhythmPair(
              expected: ExpectedRhythmEvent(
                id: 2,
                noteIndex: 1,
                timeSeconds: 0.1,
              ),
              tap: TapInputEvent(id: 2, timeSeconds: 0.112),
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
    await notifier.init();

    await tester.pumpWidget(_wrap(notifier, platform: TargetPlatform.macOS));
    await tester.pump();

    await tester.runAsync(() async {
      await notifier.performPrimaryAction();
      await Future<void>.delayed(const Duration(milliseconds: 900));
    });
    await tester.pump();

    expect(find.text('Clean, but loose'), findsOneWidget);
    expect(
      find.text("You're consistently late. Keep BPM and tap slightly earlier."),
      findsOneWidget,
    );
  });

  testWidgets('result card shows perfect recommendation', (
    WidgetTester tester,
  ) async {
    final notifier = _buildNotifier(
      matcher: _FixedMatcher(
        const RhythmTestResult(
          matchedPairs: [
            MatchedRhythmPair(
              expected: ExpectedRhythmEvent(
                id: 1,
                noteIndex: 0,
                timeSeconds: 0,
              ),
              tap: TapInputEvent(id: 1, timeSeconds: 0.002),
              errorSeconds: 0.002,
            ),
            MatchedRhythmPair(
              expected: ExpectedRhythmEvent(
                id: 2,
                noteIndex: 1,
                timeSeconds: 0.1,
              ),
              tap: TapInputEvent(id: 2, timeSeconds: 0.102),
              errorSeconds: 0.002,
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
    await notifier.init();

    await tester.pumpWidget(_wrap(notifier, platform: TargetPlatform.macOS));
    await tester.pump();

    await tester.runAsync(() async {
      await notifier.performPrimaryAction();
      await Future<void>.delayed(const Duration(milliseconds: 900));
    });
    await tester.pump();

    expect(find.text('Perfect'), findsOneWidget);
    expect(find.text('Raise BPM by 5–10 and retry.'), findsOneWidget);
  });
}

ThemeData? _themeForPlatform(TargetPlatform? platform) {
  if (platform == null) {
    return null;
  }
  return ThemeData(platform: platform);
}

Widget _wrap(RhythmTestNotifier notifier, {TargetPlatform? platform}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ScoreNotifier()),
      ChangeNotifierProvider.value(value: notifier),
    ],
    child: MaterialApp(
      theme: _themeForPlatform(platform),
      home: Scaffold(
        body: RhythmTestWorkspace(
          layoutProfile: WorkspaceLayoutProfile.fromSize(const Size(430, 932)),
          onTempoChanged: notifier.setTempo,
          onRendererKeyDown: _ignoreRendererKeyDown,
        ),
      ),
    ),
  );
}

bool _ignoreRendererKeyDown(String? key, String? code, bool repeat) => false;

RhythmTestNotifier _buildNotifier({
  RhythmMatcher? matcher,
  Future<void> Function()? waitBeforeScoring,
}) {
  return RhythmTestNotifier(
    score: Score(
      bpm: 120,
      notes: const [
        Note(midi: 60, duration: NoteDuration.quarter),
        Note(midi: 62, duration: NoteDuration.quarter),
      ],
    ),
    matcher: matcher,
    waitBeforeScoring: waitBeforeScoring,
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

class _FixedTimelineBuilder extends RhythmTimelineBuilder {
  const _FixedTimelineBuilder(this.timeline);

  final RhythmTimeline timeline;

  @override
  RhythmTimeline build(Score score) => timeline;
}

class _FakeAudioService extends AudioService {
  int _nextHandleId = 1;

  @override
  Future<bool> init({
    Duration webTimeout = const Duration(seconds: 12),
  }) async => true;

  @override
  Future<AudioNoteHandle?> startNote(
    int midi, {
    int velocity = AudioService.defaultPlaybackVelocity,
  }) async => AudioNoteHandle(id: _nextHandleId++, midi: midi);

  @override
  Future<void> stopNoteHandle(AudioNoteHandle handle) async {}

  @override
  void playRhythmTestMetronomeClick({required bool accented}) {}

  @override
  void stopPlayback() {}

  @override
  void dispose() {}
}
