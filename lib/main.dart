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
    super.key,
  });

  final PresetScoreRepository? presetScoreRepository;
  final ScoreLibraryRepository? scoreLibraryRepository;
  final ScoreTransferService? scoreTransferService;
  final WorkspaceRepository? workspaceRepository;
  final AudioService? rhythmTestAudioService;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyAppShellReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tap Score',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerDelegate: _routerDelegate,
      routeInformationParser: _routeInformationParser,
    );
  }
}
