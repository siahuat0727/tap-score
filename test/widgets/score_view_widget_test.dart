import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/widgets/score_view_widget.dart';

void main() {
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
