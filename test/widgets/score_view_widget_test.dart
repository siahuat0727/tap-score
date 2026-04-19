import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/state/score_notifier.dart';
import 'package:tap_score/widgets/score_view_widget.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers/fake_webview_platform.dart';

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  setUp(() {
    FakeWebViewPlatform.reset();
  });

  test('first flush sends static, rhythm overlay, and playback commands', () {
    final controller = ScoreRendererCommandController();

    final commands = controller.buildCommands(
      staticPayload: _staticPayload(selectedIndex: -1),
      rhythmOverlayPayload: _rhythmOverlayPayload(playheadTimeSeconds: -0.4),
      playbackIndex: -1,
      overlayChanged: true,
      playbackChanged: true,
    );

    expect(commands.map((command) => command['type']).toList(), [
      'renderScoreStatic',
      'updateRhythmOverlay',
      'updatePlaybackIndex',
    ]);
    expect(commands.map((command) => command['commandId']).toList(), [1, 2, 3]);
  });

  test('rhythm overlay changes do not require a static render', () {
    final controller = ScoreRendererCommandController();

    controller.buildCommands(
      staticPayload: _staticPayload(selectedIndex: -1),
      rhythmOverlayPayload: _rhythmOverlayPayload(playheadTimeSeconds: -0.4),
      playbackIndex: -1,
      overlayChanged: true,
      playbackChanged: true,
    );

    final commands = controller.buildCommands(
      rhythmOverlayPayload: _rhythmOverlayPayload(playheadTimeSeconds: -0.2),
      playbackIndex: -1,
      overlayChanged: true,
    );

    expect(commands, hasLength(1));
    expect(commands.single['type'], 'updateRhythmOverlay');
    expect(commands.single['commandId'], 4);
  });

  test('playback changes do not require a static render', () {
    final controller = ScoreRendererCommandController();

    controller.buildCommands(
      staticPayload: _staticPayload(selectedIndex: -1),
      rhythmOverlayPayload: _rhythmOverlayPayload(playheadTimeSeconds: -0.4),
      playbackIndex: -1,
      overlayChanged: true,
      playbackChanged: true,
    );

    final commands = controller.buildCommands(
      rhythmOverlayPayload: _rhythmOverlayPayload(playheadTimeSeconds: -0.4),
      playbackIndex: 2,
      playbackChanged: true,
    );

    expect(commands, hasLength(1));
    expect(commands.single['type'], 'updatePlaybackIndex');
    expect(commands.single['playbackIndex'], 2);
    expect(commands.single['commandId'], 4);
  });

  test('static payload changes resend the static render path', () {
    final controller = ScoreRendererCommandController();

    controller.buildCommands(
      staticPayload: _staticPayload(selectedIndex: -1),
      rhythmOverlayPayload: _rhythmOverlayPayload(playheadTimeSeconds: -0.4),
      playbackIndex: 1,
      overlayChanged: true,
      playbackChanged: true,
    );

    final commands = controller.buildCommands(
      staticPayload: _staticPayload(selectedIndex: 0),
      rhythmOverlayPayload: _rhythmOverlayPayload(playheadTimeSeconds: -0.4),
      playbackIndex: 1,
    );

    expect(commands.map((command) => command['type']).toList(), [
      'renderScoreStatic',
      'updateRhythmOverlay',
      'updatePlaybackIndex',
    ]);
    expect(commands.map((command) => command['commandId']).toList(), [4, 5, 6]);
  });

  testWidgets('missing renderer acknowledgement shows retry overlay', (
    WidgetTester tester,
  ) async {
    FakeWebViewPlatform.autoDispatchCommandApplied = false;

    await tester.pumpWidget(
      _buildScoreViewHarness(
        notifier: ScoreNotifier(),
        rendererCommandTimeout: const Duration(milliseconds: 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const ValueKey('score-renderer-retry')), findsOneWidget);
    expect(find.text('Score renderer stopped responding.'), findsOneWidget);
  });

  testWidgets('renderer retry overlay clears after acknowledgement resumes', (
    WidgetTester tester,
  ) async {
    FakeWebViewPlatform.autoDispatchCommandApplied = false;

    await tester.pumpWidget(
      _buildScoreViewHarness(
        notifier: ScoreNotifier(),
        rendererCommandTimeout: const Duration(milliseconds: 10),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    FakeWebViewPlatform.autoDispatchCommandApplied = true;
    await tester.tap(find.byKey(const ValueKey('score-renderer-retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const ValueKey('score-renderer-retry')), findsNothing);
    expect(find.text('Score renderer stopped responding.'), findsNothing);
  });
}

Map<String, dynamic> _staticPayload({required int selectedIndex}) {
  return {
    'clef': 'treble',
    'restAnchorPitch': 'b/4',
    'beatsPerMeasure': 4,
    'beatUnit': 4,
    'keySignatureStr': 'C',
    'alteredPitches': const <int>[],
    'accidentalOffset': 0,
    'notes': const [
      {
        'midi': 60,
        'duration': 'quarter',
        'beats': 1.0,
        'isRest': false,
        'isDotted': false,
        'slurToNext': false,
        'tripletGroupId': null,
      },
    ],
    'selectedIndex': selectedIndex,
    'cursorIndex': 0,
    'selectionKind': selectedIndex >= 0 ? 'note' : '',
    'showsRhythmOverlay': true,
    'title': '',
    'bpm': 120,
  };
}

Widget _buildScoreViewHarness({
  required ScoreNotifier notifier,
  required Duration rendererCommandTimeout,
}) {
  return ChangeNotifierProvider.value(
    value: notifier,
    child: MaterialApp(
      home: Scaffold(
        body: ScoreViewWidget(rendererCommandTimeout: rendererCommandTimeout),
      ),
    ),
  );
}

Map<String, dynamic> _rhythmOverlayPayload({
  required double playheadTimeSeconds,
}) {
  return {
    'phase': 'live',
    'shouldAutoFollowPlayback': true,
    'elapsedRunSeconds': 0.0,
    'playheadTimeSeconds': playheadTimeSeconds,
    'countInDurationSeconds': 0.4,
    'totalDurationSeconds': 1.0,
    'pulseDurationSeconds': 0.1,
    'pulsesPerMeasure': 4,
    'measureBoundaryTimesSeconds': const [0.0, 1.0],
    'expectedEvents': const [],
    'liveTapEvents': const [],
    'resultTapEvents': const [],
    'matchedPairs': const [],
    'appliedShiftSeconds': 0.0,
    'errorLabelThresholdBeats': 0.05,
    'largeErrorThresholdBeats': 0.1,
    'largeErrorNoteIndices': const [],
    'missedExpectedNoteIndices': const [],
  };
}
