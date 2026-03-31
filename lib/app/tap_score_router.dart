import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/launch_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/score_editor_screen.dart';
import '../services/preset_score_repository.dart';
import '../services/score_library_repository.dart';
import '../services/score_transfer_service.dart';
import '../state/score_notifier.dart';
import 'editor_launch_config.dart';
import 'practice_launch_config.dart';

sealed class TapScoreRouteState {
  const TapScoreRouteState();

  String get routeLocation;
}

class TapScoreHomeRouteState extends TapScoreRouteState {
  const TapScoreHomeRouteState();

  @override
  String get routeLocation => '/';
}

class TapScoreEditorRouteState extends TapScoreRouteState {
  const TapScoreEditorRouteState(this.launchConfig);

  final EditorLaunchConfig launchConfig;

  @override
  String get routeLocation => launchConfig.routeLocation;
}

class TapScorePracticeRouteState extends TapScoreRouteState {
  const TapScorePracticeRouteState(this.launchConfig);

  final PracticeLaunchConfig launchConfig;

  @override
  String get routeLocation => launchConfig.routeLocation;
}

class TapScoreRouteInformationParser extends RouteInformationParser<Object> {
  @override
  Future<Object> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    final normalizedPath = uri.path.isEmpty ? '/' : uri.path;
    if (normalizedPath == '/' || normalizedPath == '') {
      return const TapScoreHomeRouteState();
    }

    if (normalizedPath == '/editor') {
      final presetId = uri.queryParameters['preset']?.trim();
      if (presetId != null && presetId.isNotEmpty) {
        return TapScoreEditorRouteState(EditorLaunchConfig.preset(presetId));
      }

      final mode = uri.queryParameters['mode']?.trim();
      if (mode == null || mode == 'blank') {
        return const TapScoreEditorRouteState(EditorLaunchConfig.blank());
      }
    }

    if (normalizedPath == '/practice') {
      final presetId = uri.queryParameters['preset']?.trim();
      if (presetId != null && presetId.isNotEmpty) {
        return TapScorePracticeRouteState(PracticeLaunchConfig(presetId));
      }
    }

    return const TapScoreHomeRouteState();
  }

  @override
  RouteInformation? restoreRouteInformation(Object? configuration) {
    final routeState = configuration as TapScoreRouteState?;
    final location = routeState?.routeLocation ?? '/';
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

  TapScoreRouteState _routeState = const TapScoreHomeRouteState();

  @override
  Object? get currentConfiguration => _routeState;

  bool get _isHomeRoute => _routeState is TapScoreHomeRouteState;

  void showHome() {
    if (_isHomeRoute) {
      return;
    }
    _routeState = const TapScoreHomeRouteState();
    notifyListeners();
  }

  void showBlankEditor() {
    _routeState = const TapScoreEditorRouteState(EditorLaunchConfig.blank());
    notifyListeners();
  }

  void showPresetEditor(String presetId) {
    _routeState = TapScoreEditorRouteState(EditorLaunchConfig.preset(presetId));
    notifyListeners();
  }

  void showPracticePreset(String presetId) {
    _routeState = TapScorePracticeRouteState(PracticeLaunchConfig(presetId));
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {
    _routeState = configuration as TapScoreRouteState;
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_routeState) {
      TapScoreHomeRouteState() => MaterialPage<void>(
        key: const ValueKey('tap-score-home-page'),
        child: LaunchScreen(
          presetScoreRepository: presetScoreRepository,
          onStartBlank: showBlankEditor,
          onStartPracticePreset: showPracticePreset,
        ),
      ),
      TapScoreEditorRouteState(:final launchConfig) => MaterialPage<void>(
        key: ValueKey(launchConfig.routeLocation),
        child: ChangeNotifierProvider(
          create: (_) => ScoreNotifier(
            scoreLibraryRepository: scoreLibraryRepository,
            presetScoreRepository: presetScoreRepository,
          ),
          child: ScoreEditorScreen(
            launchConfig: launchConfig,
            scoreTransferService: scoreTransferService,
            onGoHome: showHome,
          ),
        ),
      ),
      TapScorePracticeRouteState(:final launchConfig) => MaterialPage<void>(
        key: ValueKey(launchConfig.routeLocation),
        child: ChangeNotifierProvider(
          create: (_) => ScoreNotifier(
            scoreLibraryRepository: scoreLibraryRepository,
            presetScoreRepository: presetScoreRepository,
          ),
          child: PracticeScreen(
            launchConfig: launchConfig,
            presetScoreRepository: presetScoreRepository,
            onGoHome: showHome,
            onChoosePreset: showPracticePreset,
            onOpenInEditor: showPresetEditor,
          ),
        ),
      ),
    };

    return Navigator(
      key: navigatorKey,
      pages: [page],
      onDidRemovePage: (page) {
        if (!_isHomeRoute) {
          showHome();
        }
      },
    );
  }
}
