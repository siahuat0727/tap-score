import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/portable_score_document.dart';
import '../screens/launch_screen.dart';
import '../screens/workspace_screen.dart';
import '../services/audio_service.dart';
import '../services/preset_score_repository.dart';
import '../services/score_library_repository.dart';
import '../services/score_transfer_service.dart';
import '../state/score_notifier.dart';
import '../workspace/workspace_repository.dart';
import 'workspace_launch_config.dart';

sealed class TapScoreRouteState {
  const TapScoreRouteState();

  String get routeLocation;
}

class TapScoreHomeRouteState extends TapScoreRouteState {
  const TapScoreHomeRouteState();

  @override
  String get routeLocation => '/';
}

class TapScoreWorkspaceRouteState extends TapScoreRouteState {
  const TapScoreWorkspaceRouteState({
    required this.launchConfig,
    required this.routeLocation,
  });

  final WorkspaceLaunchConfig launchConfig;

  @override
  final String routeLocation;

  TapScoreWorkspaceRouteState copyWith({
    WorkspaceLaunchConfig? launchConfig,
    String? routeLocation,
  }) {
    return TapScoreWorkspaceRouteState(
      launchConfig: launchConfig ?? this.launchConfig,
      routeLocation: routeLocation ?? this.routeLocation,
    );
  }
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
        return TapScoreWorkspaceRouteState(
          launchConfig: WorkspaceLaunchConfig.preset(
            presetId,
            initialMode: WorkspaceMode.compose,
          ),
          routeLocation: uri.toString(),
        );
      }

      final mode = uri.queryParameters['mode']?.trim();
      if (mode == 'blank') {
        return const TapScoreWorkspaceRouteState(
          launchConfig: WorkspaceLaunchConfig.blank(),
          routeLocation: '/editor?mode=blank',
        );
      }

      return const TapScoreWorkspaceRouteState(
        launchConfig: WorkspaceLaunchConfig.restore(
          initialMode: WorkspaceMode.compose,
        ),
        routeLocation: '/editor',
      );
    }

    if (normalizedPath == '/practice') {
      final presetId = uri.queryParameters['preset']?.trim();
      if (presetId != null && presetId.isNotEmpty) {
        return TapScoreWorkspaceRouteState(
          launchConfig: WorkspaceLaunchConfig.preset(
            presetId,
            initialMode: WorkspaceMode.rhythmTest,
          ),
          routeLocation: uri.toString(),
        );
      }

      return const TapScoreWorkspaceRouteState(
        launchConfig: WorkspaceLaunchConfig.restore(
          initialMode: WorkspaceMode.rhythmTest,
        ),
        routeLocation: '/practice',
      );
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
    this.rhythmTestAudioService,
    WorkspaceRepository? workspaceRepository,
  }) : _workspaceRepository =
           workspaceRepository ??
           DefaultWorkspaceRepository(
             scoreLibraryRepository: scoreLibraryRepository,
             presetScoreRepository: presetScoreRepository,
           );

  final PresetScoreRepository? presetScoreRepository;
  final ScoreLibraryRepository? scoreLibraryRepository;
  final ScoreTransferService? scoreTransferService;
  final AudioService? rhythmTestAudioService;
  final WorkspaceRepository _workspaceRepository;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  TapScoreRouteState _routeState = const TapScoreHomeRouteState();
  int _workspaceSession = 0;

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

  void showBlankWorkspace() {
    _showWorkspace(const WorkspaceLaunchConfig.blank());
  }

  void showPracticePreset(String presetId) {
    _showWorkspace(
      WorkspaceLaunchConfig.preset(
        presetId,
        initialMode: WorkspaceMode.rhythmTest,
      ),
    );
  }

  void showPracticeSaved(String savedScoreId) {
    _showWorkspace(
      WorkspaceLaunchConfig.saved(
        savedScoreId,
        initialMode: WorkspaceMode.rhythmTest,
      ),
    );
  }

  void showImportedDocument(PortableScoreDocument document) {
    _showWorkspace(WorkspaceLaunchConfig.imported(document));
  }

  void syncWorkspaceRoute(WorkspaceMode mode, String? shareablePresetId) {
    final routeState = _routeState;
    if (routeState is! TapScoreWorkspaceRouteState) {
      return;
    }

    final nextLocation = WorkspaceLaunchConfig.routeLocationFor(
      mode: mode,
      presetId: shareablePresetId,
    );
    if (routeState.routeLocation == nextLocation) {
      return;
    }

    _routeState = routeState.copyWith(routeLocation: nextLocation);
    notifyListeners();
  }

  void _showWorkspace(WorkspaceLaunchConfig launchConfig) {
    _workspaceSession += 1;
    _routeState = TapScoreWorkspaceRouteState(
      launchConfig: launchConfig,
      routeLocation: launchConfig.routeLocation,
    );
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(Object configuration) async {
    _routeState = configuration as TapScoreRouteState;
    if (configuration is TapScoreWorkspaceRouteState) {
      _workspaceSession += 1;
    }
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_routeState) {
      TapScoreHomeRouteState() => MaterialPage<void>(
        key: const ValueKey('tap-score-home-page'),
        child: LaunchScreen(
          presetScoreRepository: presetScoreRepository,
          scoreLibraryRepository: scoreLibraryRepository,
          scoreTransferService: scoreTransferService,
          onStartBlank: showBlankWorkspace,
          onStartPracticePreset: showPracticePreset,
          onStartPracticeSaved: showPracticeSaved,
          onImportDocument: showImportedDocument,
        ),
      ),
      TapScoreWorkspaceRouteState(:final launchConfig) => MaterialPage<void>(
        key: ValueKey('tap-score-workspace-page-$_workspaceSession'),
        child: ChangeNotifierProvider(
          create: (_) =>
              ScoreNotifier(workspaceRepository: _workspaceRepository),
          child: WorkspaceScreen(
            launchConfig: launchConfig,
            scoreTransferService: scoreTransferService,
            rhythmTestAudioService: rhythmTestAudioService,
            onGoHome: showHome,
            onRouteSync: syncWorkspaceRoute,
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
