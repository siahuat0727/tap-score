import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/launch_screen.dart';
import '../screens/score_editor_screen.dart';
import '../services/preset_score_repository.dart';
import '../services/score_library_repository.dart';
import '../services/score_transfer_service.dart';
import '../state/score_notifier.dart';
import 'editor_launch_config.dart';

class TapScoreRouteState {
  const TapScoreRouteState.home() : launchConfig = null;

  const TapScoreRouteState.editor(this.launchConfig);

  final EditorLaunchConfig? launchConfig;

  bool get isHome => launchConfig == null;
}

class TapScoreRouteInformationParser extends RouteInformationParser<Object> {
  @override
  Future<Object> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    final normalizedPath = uri.path.isEmpty ? '/' : uri.path;
    if (normalizedPath == '/' || normalizedPath == '') {
      return const TapScoreRouteState.home();
    }
    if (normalizedPath != '/editor') {
      return const TapScoreRouteState.home();
    }

    final presetId = uri.queryParameters['preset']?.trim();
    if (presetId != null && presetId.isNotEmpty) {
      return TapScoreRouteState.editor(EditorLaunchConfig.preset(presetId));
    }

    final mode = uri.queryParameters['mode']?.trim();
    if (mode == null || mode == 'blank') {
      return const TapScoreRouteState.editor(EditorLaunchConfig.blank());
    }

    return const TapScoreRouteState.home();
  }

  @override
  RouteInformation? restoreRouteInformation(Object? configuration) {
    final routeState = configuration as TapScoreRouteState?;
    final launchConfig = routeState?.launchConfig;
    final location = launchConfig?.routeLocation ?? '/';
    return RouteInformation(uri: Uri.parse(location));
  }
}

class TapScoreRouterDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  TapScoreRouterDelegate({
    this.presetScoreRepository,
    this.scoreLibraryRepository,
    this.scoreTransferService,
  });

  final PresetScoreRepository? presetScoreRepository;
  final ScoreLibraryRepository? scoreLibraryRepository;
  final ScoreTransferService? scoreTransferService;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  TapScoreRouteState _routeState = const TapScoreRouteState.home();

  @override
  Object? get currentConfiguration => _routeState;

  void showHome() {
    if (_routeState.isHome) {
      return;
    }
    _routeState = const TapScoreRouteState.home();
    notifyListeners();
  }

  void showBlankEditor() {
    _routeState = const TapScoreRouteState.editor(EditorLaunchConfig.blank());
    notifyListeners();
  }

  void showPresetEditor(String presetId) {
    _routeState = TapScoreRouteState.editor(
      EditorLaunchConfig.preset(presetId),
    );
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {
    _routeState = configuration as TapScoreRouteState;
  }

  @override
  Widget build(BuildContext context) {
    final launchConfig = _routeState.launchConfig;
    final page = _routeState.isHome
        ? MaterialPage<void>(
            key: const ValueKey('tap-score-home-page'),
            child: LaunchScreen(
              presetScoreRepository: presetScoreRepository,
              onStartBlank: showBlankEditor,
              onStartPreset: showPresetEditor,
            ),
          )
        : MaterialPage<void>(
            key: ValueKey(launchConfig!.routeLocation),
            child: ChangeNotifierProvider(
              create: (_) => ScoreNotifier(
                scoreLibraryRepository: scoreLibraryRepository,
                presetScoreRepository: presetScoreRepository,
              ),
              child: ScoreEditorScreen(
                launchConfig: launchConfig,
                scoreTransferService: scoreTransferService,
              ),
            ),
          );

    return Navigator(
      key: navigatorKey,
      pages: [page],
      onDidRemovePage: (page) {
        if (!_routeState.isHome) {
          showHome();
        }
      },
    );
  }
}
