import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/app/editor_launch_config.dart';
import 'package:tap_score/app/practice_launch_config.dart';
import 'package:tap_score/app/tap_score_router.dart';

void main() {
  final parser = TapScoreRouteInformationParser();

  test('route parser supports home, editor, and practice states', () async {
    final home = await parser.parseRouteInformation(
      RouteInformation(uri: Uri(path: '/')),
    );
    final blankEditor = await parser.parseRouteInformation(
      RouteInformation(
        uri: Uri(path: '/editor', queryParameters: {'mode': 'blank'}),
      ),
    );
    final presetEditor = await parser.parseRouteInformation(
      RouteInformation(
        uri: Uri(path: '/editor', queryParameters: {'preset': 'triplet-study'}),
      ),
    );
    final practice = await parser.parseRouteInformation(
      RouteInformation(
        uri: Uri(
          path: '/practice',
          queryParameters: {'preset': 'triplet-study'},
        ),
      ),
    );

    expect(home, isA<TapScoreHomeRouteState>());
    expect(blankEditor, isA<TapScoreEditorRouteState>());
    expect(
      (blankEditor as TapScoreEditorRouteState).launchConfig.isBlank,
      isTrue,
    );
    expect(presetEditor, isA<TapScoreEditorRouteState>());
    expect(
      (presetEditor as TapScoreEditorRouteState).launchConfig.presetId,
      'triplet-study',
    );
    expect(practice, isA<TapScorePracticeRouteState>());
    expect(
      (practice as TapScorePracticeRouteState).launchConfig.presetId,
      'triplet-study',
    );
  });

  test('route restoration returns stable locations', () {
    expect(
      parser
          .restoreRouteInformation(const TapScoreHomeRouteState())
          ?.uri
          .toString(),
      '/',
    );
    expect(
      parser
          .restoreRouteInformation(
            const TapScoreEditorRouteState(EditorLaunchConfig.blank()),
          )
          ?.uri
          .toString(),
      '/editor?mode=blank',
    );
    expect(
      parser
          .restoreRouteInformation(
            TapScoreEditorRouteState(
              EditorLaunchConfig.preset('triplet-study'),
            ),
          )
          ?.uri
          .toString(),
      '/editor?preset=triplet-study',
    );
    expect(
      parser
          .restoreRouteInformation(
            const TapScorePracticeRouteState(
              PracticeLaunchConfig('triplet-study'),
            ),
          )
          ?.uri
          .toString(),
      '/practice?preset=triplet-study',
    );
  });
}
