import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/app/tap_score_router.dart';
import 'package:tap_score/app/workspace_launch_config.dart';

void main() {
  final parser = TapScoreRouteInformationParser();

  test('route parser converges editor and practice entry URLs', () async {
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
    final practicePreset = await parser.parseRouteInformation(
      RouteInformation(
        uri: Uri(
          path: '/practice',
          queryParameters: {'preset': 'triplet-study'},
        ),
      ),
    );

    expect(home, isA<TapScoreHomeRouteState>());
    expect(blankEditor, isA<TapScoreWorkspaceRouteState>());
    expect(
      (blankEditor as TapScoreWorkspaceRouteState).launchConfig.isBlank,
      isTrue,
    );
    expect(blankEditor.launchConfig.initialMode, WorkspaceMode.compose);

    expect(presetEditor, isA<TapScoreWorkspaceRouteState>());
    expect(
      (presetEditor as TapScoreWorkspaceRouteState).launchConfig.presetId,
      'triplet-study',
    );
    expect(presetEditor.launchConfig.initialMode, WorkspaceMode.compose);

    expect(practicePreset, isA<TapScoreWorkspaceRouteState>());
    expect(
      (practicePreset as TapScoreWorkspaceRouteState).launchConfig.presetId,
      'triplet-study',
    );
    expect(practicePreset.launchConfig.initialMode, WorkspaceMode.rhythmTest);
  });

  test('route restoration returns unified workspace locations', () {
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
            const TapScoreWorkspaceRouteState(
              launchConfig: WorkspaceLaunchConfig.blank(),
              routeLocation: '/editor?mode=blank',
            ),
          )
          ?.uri
          .toString(),
      '/editor?mode=blank',
    );
    expect(
      parser
          .restoreRouteInformation(
            TapScoreWorkspaceRouteState(
              launchConfig: WorkspaceLaunchConfig.preset(
                'triplet-study',
                initialMode: WorkspaceMode.compose,
              ),
              routeLocation: '/editor?preset=triplet-study',
            ),
          )
          ?.uri
          .toString(),
      '/editor?preset=triplet-study',
    );
    expect(
      parser
          .restoreRouteInformation(
            TapScoreWorkspaceRouteState(
              launchConfig: WorkspaceLaunchConfig.preset(
                'triplet-study',
                initialMode: WorkspaceMode.rhythmTest,
              ),
              routeLocation: '/practice?preset=triplet-study',
            ),
          )
          ?.uri
          .toString(),
      '/practice?preset=triplet-study',
    );
  });

  test(
    'router delegate notifies when a direct workspace route is applied',
    () async {
      final delegate = TapScoreRouterDelegate();
      var notifications = 0;
      delegate.addListener(() {
        notifications += 1;
      });

      await delegate.setNewRoutePath(
        const TapScoreWorkspaceRouteState(
          launchConfig: WorkspaceLaunchConfig.blank(),
          routeLocation: '/editor?mode=blank',
        ),
      );

      expect(notifications, 1);
      expect(delegate.currentConfiguration, isA<TapScoreWorkspaceRouteState>());
    },
  );
}
