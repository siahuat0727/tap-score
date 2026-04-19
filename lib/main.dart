import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_shell_ready_bridge.dart';
import 'app/tap_score_router.dart';
import 'services/audio_service.dart';
import 'services/preset_score_repository.dart';
import 'services/score_library_repository.dart';
import 'services/score_transfer_service.dart';
import 'theme/app_theme.dart';
import 'workspace/workspace_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TapScoreApp());
}

class TapScoreApp extends StatefulWidget {
  const TapScoreApp({
    this.presetScoreRepository,
    this.scoreLibraryRepository,
    this.scoreTransferService,
    this.workspaceRepository,
    this.rhythmTestAudioService,
    this.routeInformationProvider,
    super.key,
  });

  final PresetScoreRepository? presetScoreRepository;
  final ScoreLibraryRepository? scoreLibraryRepository;
  final ScoreTransferService? scoreTransferService;
  final WorkspaceRepository? workspaceRepository;
  final AudioService? rhythmTestAudioService;
  final RouteInformationProvider? routeInformationProvider;

  @override
  State<TapScoreApp> createState() => _TapScoreAppState();
}

class _TapScoreAppState extends State<TapScoreApp> {
  late final TapScoreRouterDelegate _routerDelegate = TapScoreRouterDelegate(
    presetScoreRepository: widget.presetScoreRepository,
    scoreLibraryRepository: widget.scoreLibraryRepository,
    scoreTransferService: widget.scoreTransferService,
    workspaceRepository: widget.workspaceRepository,
    rhythmTestAudioService: widget.rhythmTestAudioService,
  );
  final TapScoreRouteInformationParser _routeInformationParser =
      TapScoreRouteInformationParser();
  PlatformRouteInformationProvider? _ownedRouteInformationProvider;

  @override
  void initState() {
    super.initState();
    _syncRouteInformationProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyAppShellReady();
    });
  }

  @override
  void didUpdateWidget(covariant TapScoreApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeInformationProvider != widget.routeInformationProvider) {
      _syncRouteInformationProvider();
    }
  }

  @override
  void dispose() {
    _ownedRouteInformationProvider?.dispose();
    super.dispose();
  }

  void _syncRouteInformationProvider() {
    _ownedRouteInformationProvider?.dispose();
    _ownedRouteInformationProvider = null;

    if (widget.routeInformationProvider != null || !kIsWeb) {
      return;
    }

    _ownedRouteInformationProvider = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: Uri.base),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tap Score',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerDelegate: _routerDelegate,
      routeInformationParser: _routeInformationParser,
      routeInformationProvider:
          widget.routeInformationProvider ?? _ownedRouteInformationProvider,
    );
  }
}
