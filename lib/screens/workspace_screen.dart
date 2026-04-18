import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/app_shell_ready_bridge.dart';
import '../app/score_seed_config.dart';
import '../app/workspace_launch_config.dart';
import '../input/editor_shortcuts.dart';
import '../services/audio_service.dart';
import '../services/score_transfer_service.dart';
import '../state/rhythm_test_notifier.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/duration_selector.dart';
import '../widgets/input_affordance.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/playback_controls.dart';
import '../widgets/rhythm_test_workspace.dart';
import '../widgets/score_view_widget.dart';
import '../widgets/workspace_top_bar.dart';

typedef WorkspaceRouteSync =
    void Function(WorkspaceMode mode, String? shareablePresetId);

enum _WorkspaceStartupPhase {
  preparingWorkspace,
  preparingRenderer,
  preparingRhythmTestAudio,
  retryingRhythmTestAudio,
  ready,
  failed,
}

enum _WorkspaceStartupFailureKind { workspace, rhythmTestAudio }

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    this.launchConfig = const WorkspaceLaunchConfig.blank(),
    this.scoreTransferService,
    this.rhythmTestAudioService,
    this.onGoHome,
    this.onRouteSync,
    super.key,
  });

  final WorkspaceLaunchConfig launchConfig;
  final ScoreTransferService? scoreTransferService;
  final AudioService? rhythmTestAudioService;
  final VoidCallback? onGoHome;
  final WorkspaceRouteSync? onRouteSync;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  static const Duration _webAudioTimeout = Duration(seconds: 12);

  final FocusNode _focusNode = FocusNode();
  late final ScoreTransferService _scoreTransferService =
      widget.scoreTransferService ?? PlatformScoreTransferService();
  late WorkspaceMode _mode = widget.launchConfig.initialMode;
  RhythmTestNotifier? _rhythmTestNotifier;
  _WorkspaceStartupPhase _startupPhase =
      _WorkspaceStartupPhase.preparingWorkspace;
  _WorkspaceStartupFailureKind? _startupFailureKind;
  String? _startupErrorMessage;
  String _workspaceStepLabel = '';
  String _rendererStepLabel = 'Loading score renderer';
  String _audioStepLabel = 'Initializing Web Audio';
  int _startupPass = 0;
  int _rendererSession = 0;
  bool _workspacePrepared = false;
  bool _rendererReady = false;
  bool _audioReady = false;

  bool get _startupReady => _startupPhase == _WorkspaceStartupPhase.ready;
  bool get _startupFailed => _startupPhase == _WorkspaceStartupPhase.failed;
  bool get _showsStartupOverlay => !_startupReady;

  @override
  void initState() {
    super.initState();
    _workspaceStepLabel = _workspaceLabelForLaunchConfig(widget.launchConfig);
    _rendererStepLabel = _rendererLabelForMode(_mode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_startStartupFlow());
    });
  }

  @override
  void dispose() {
    _rhythmTestNotifier?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startStartupFlow() async {
    final scoreNotifier = context.read<ScoreNotifier>();
    final pass = ++_startupPass;

    _disposeRhythmTestNotifier();
    _rendererSession += 1;
    setState(() {
      _startupPhase = _WorkspaceStartupPhase.preparingWorkspace;
      _startupFailureKind = null;
      _startupErrorMessage = null;
      _workspacePrepared = false;
      _rendererReady = false;
      _audioReady = _mode == WorkspaceMode.compose;
      _workspaceStepLabel = _workspaceLabelForLaunchConfig(widget.launchConfig);
      _rendererStepLabel = _rendererLabelForMode(_mode);
      _audioStepLabel = 'Initializing Web Audio';
    });
    _publishBrowserStartupState();

    await scoreNotifier.init(
      initialScoreConfig: widget.launchConfig.seedConfig,
    );
    if (!mounted || pass != _startupPass) {
      return;
    }

    if (!scoreNotifier.initialWorkspaceLoadSucceeded) {
      _failStartup(
        kind: _WorkspaceStartupFailureKind.workspace,
        message:
            scoreNotifier.libraryMessage ?? 'Failed to load the workspace.',
      );
      return;
    }

    _configureBodyAfterWorkspaceLoad(scoreNotifier);
    if (!mounted || pass != _startupPass) {
      return;
    }

    _maybeCompleteStartup(scoreNotifier);
    if (_startupReady) {
      return;
    }

    if (_requiresRhythmTestAudioGate(scoreNotifier)) {
      unawaited(_prepareRhythmTestAudio(pass: pass, attempt: 1));
      return;
    }

    setState(() {
      _startupPhase = _WorkspaceStartupPhase.preparingRenderer;
    });
    _publishBrowserStartupState();
  }

  Future<void> _switchMode(WorkspaceMode nextMode) async {
    if (!_startupReady || nextMode == _mode) {
      return;
    }

    if (nextMode == WorkspaceMode.compose) {
      final scoreNotifier = context.read<ScoreNotifier>();
      _rendererSession += 1;
      setState(() {
        _mode = WorkspaceMode.compose;
        _rendererReady = false;
        _audioReady = true;
        _rendererStepLabel = _rendererLabelForMode(WorkspaceMode.compose);
      });
      _disposeRhythmTestNotifier();
      _beginBlockingStartup(
        phase: _WorkspaceStartupPhase.preparingRenderer,
        workspaceLabel: 'Current workspace ready',
      );
      _maybeCompleteStartup(scoreNotifier);
      _syncRoute();
      return;
    }

    final scoreNotifier = context.read<ScoreNotifier>();
    scoreNotifier.stop();
    _rendererSession += 1;
    setState(() {
      _mode = WorkspaceMode.rhythmTest;
      _rendererReady = false;
      _audioReady = false;
      _rendererStepLabel = _rendererLabelForMode(WorkspaceMode.rhythmTest);
      _audioStepLabel = 'Initializing Web Audio';
    });
    _configureRhythmTestBody(scoreNotifier);
    _beginBlockingStartup(
      phase: _requiresRhythmTestAudioGate(scoreNotifier)
          ? _WorkspaceStartupPhase.preparingRhythmTestAudio
          : _WorkspaceStartupPhase.preparingRenderer,
      workspaceLabel: 'Current workspace ready',
    );
    _maybeCompleteStartup(scoreNotifier);
    if (!_startupReady && _requiresRhythmTestAudioGate(scoreNotifier)) {
      unawaited(_prepareRhythmTestAudio(pass: ++_startupPass, attempt: 1));
    }
    _syncRoute();
  }

  String? _shareablePresetId(ScoreNotifier notifier) {
    if (notifier.hasUnsavedChanges) {
      return null;
    }
    return notifier.activePresetId;
  }

  void _syncRoute() {
    final onRouteSync = widget.onRouteSync;
    if (onRouteSync == null) {
      return;
    }
    onRouteSync(_mode, _shareablePresetId(context.read<ScoreNotifier>()));
  }

  void _disposeRhythmTestNotifier() {
    final previousNotifier = _rhythmTestNotifier;
    _rhythmTestNotifier = null;
    previousNotifier?.dispose();
  }

  String _workspaceLabelForLaunchConfig(WorkspaceLaunchConfig launchConfig) {
    return switch (launchConfig.seedConfig.kind) {
      ScoreSeedKind.restore => 'Restoring last workspace',
      ScoreSeedKind.blank => 'Creating empty workspace',
      ScoreSeedKind.preset => 'Loading preset',
      ScoreSeedKind.saved => 'Loading saved score',
      ScoreSeedKind.imported => 'Importing score',
    };
  }

  String _rendererLabelForMode(WorkspaceMode mode) {
    return switch (mode) {
      WorkspaceMode.compose => 'Loading editor surface',
      WorkspaceMode.rhythmTest => 'Loading rhythm test surface',
    };
  }

  String _audioLabelForPhase(
    RhythmTestPreparationPhase phase, {
    required bool retrying,
  }) {
    return switch (phase) {
      RhythmTestPreparationPhase.initializingAudio =>
        retrying
            ? 'Retrying Web Audio initialization'
            : 'Initializing Web Audio',
      RhythmTestPreparationPhase.preloadingNotes =>
        retrying
            ? 'Retrying rhythm test note preload'
            : 'Preloading rhythm test notes',
    };
  }

  void _configureBodyAfterWorkspaceLoad(ScoreNotifier notifier) {
    _configureRhythmTestBody(notifier);
    final requiresRenderer = _requiresRendererGate(notifier);
    final requiresAudio = _requiresRhythmTestAudioGate(notifier);
    setState(() {
      _workspacePrepared = true;
      _rendererReady = !requiresRenderer;
      _audioReady = !requiresAudio;
      _startupPhase = requiresAudio
          ? _WorkspaceStartupPhase.preparingRhythmTestAudio
          : requiresRenderer
          ? _WorkspaceStartupPhase.preparingRenderer
          : _WorkspaceStartupPhase.ready;
    });
    _publishBrowserStartupState();
  }

  void _configureRhythmTestBody(ScoreNotifier scoreNotifier) {
    if (_mode != WorkspaceMode.rhythmTest) {
      _disposeRhythmTestNotifier();
      return;
    }

    scoreNotifier.stop();
    if (scoreNotifier.score.notes.isEmpty) {
      _disposeRhythmTestNotifier();
      return;
    }

    final previousNotifier = _rhythmTestNotifier;
    _rhythmTestNotifier = RhythmTestNotifier(
      score: scoreNotifier.score,
      audioService: widget.rhythmTestAudioService,
    );
    previousNotifier?.dispose();
  }

  bool _requiresRendererGate(ScoreNotifier notifier) {
    if (_mode == WorkspaceMode.compose) {
      return true;
    }
    return _rhythmTestNotifier != null && notifier.score.notes.isNotEmpty;
  }

  bool _requiresRhythmTestAudioGate(ScoreNotifier notifier) {
    if (_mode != WorkspaceMode.rhythmTest) {
      return false;
    }
    return _rhythmTestNotifier != null && notifier.score.notes.isNotEmpty;
  }

  void _beginBlockingStartup({
    required _WorkspaceStartupPhase phase,
    required String workspaceLabel,
  }) {
    setState(() {
      _startupPass += 1;
      _startupPhase = phase;
      _startupFailureKind = null;
      _startupErrorMessage = null;
      _workspacePrepared = true;
      _workspaceStepLabel = workspaceLabel;
    });
    _publishBrowserStartupState();
  }

  Future<void> _prepareRhythmTestAudio({
    required int pass,
    required int attempt,
  }) async {
    final notifier = _rhythmTestNotifier;
    if (notifier == null) {
      _audioReady = true;
      _maybeCompleteStartup(context.read<ScoreNotifier>());
      return;
    }

    final retrying = attempt > 1;
    setState(() {
      _startupPhase = retrying
          ? _WorkspaceStartupPhase.retryingRhythmTestAudio
          : _WorkspaceStartupPhase.preparingRhythmTestAudio;
      _startupFailureKind = null;
      _startupErrorMessage = null;
      _audioStepLabel = _audioLabelForPhase(
        RhythmTestPreparationPhase.initializingAudio,
        retrying: retrying,
      );
    });
    _publishBrowserStartupState();

    await notifier.init(
      audioTimeout: _webAudioTimeout,
      onPreparationPhaseChanged: (phase) {
        if (!mounted || pass != _startupPass) {
          return;
        }
        setState(() {
          _audioStepLabel = _audioLabelForPhase(phase, retrying: retrying);
        });
        _publishBrowserStartupState();
      },
    );
    if (!mounted || pass != _startupPass) {
      return;
    }

    if (notifier.isInitialized) {
      setState(() {
        _audioReady = true;
      });
      _maybeCompleteStartup(context.read<ScoreNotifier>());
      return;
    }

    if (attempt == 1) {
      final retryPass = ++_startupPass;
      setState(() {
        _startupPhase = _WorkspaceStartupPhase.retryingRhythmTestAudio;
        _audioStepLabel = 'The first audio attempt timed out. Retrying once.';
      });
      _publishBrowserStartupState();
      await _prepareRhythmTestAudio(pass: retryPass, attempt: 2);
      return;
    }

    _failStartup(
      kind: _WorkspaceStartupFailureKind.rhythmTestAudio,
      message:
          notifier.errorMessage ?? 'Rhythm test audio failed to initialize.',
    );
  }

  void _handleRendererReady(int rendererSession) {
    if (!mounted || rendererSession != _rendererSession || _rendererReady) {
      return;
    }
    setState(() {
      _rendererReady = true;
    });
    _maybeCompleteStartup(context.read<ScoreNotifier>());
  }

  void _maybeCompleteStartup(ScoreNotifier notifier) {
    final rendererReady = !_requiresRendererGate(notifier) || _rendererReady;
    final audioReady = !_requiresRhythmTestAudioGate(notifier) || _audioReady;
    if (!_workspacePrepared || !rendererReady || !audioReady) {
      _publishBrowserStartupState();
      return;
    }

    _syncRoute();
    _focusNode.requestFocus();
    setState(() {
      _startupPhase = _WorkspaceStartupPhase.ready;
      _startupFailureKind = null;
      _startupErrorMessage = null;
    });
    _publishBrowserStartupState();
  }

  void _failStartup({
    required _WorkspaceStartupFailureKind kind,
    required String message,
  }) {
    setState(() {
      _startupPhase = _WorkspaceStartupPhase.failed;
      _startupFailureKind = kind;
      _startupErrorMessage = message;
    });
    _publishBrowserStartupState();
  }

  void _publishBrowserStartupState() {
    if (_startupReady) {
      publishWorkspaceStartupState(
        title: 'Tap Score is ready',
        detail: 'Workspace setup finished.',
        workspaceLabel: _workspaceStepLabel,
        rendererLabel: _rendererStepLabel,
        workspaceState: 'complete',
        rendererState: 'complete',
        audioLabel: _requiresAudioStep ? _audioStepLabel : null,
        audioState: _requiresAudioStep ? 'complete' : null,
        dismissBootstrap: true,
      );
      return;
    }

    if (_startupFailed) {
      publishWorkspaceStartupState(
        title: 'Tap Score needs attention',
        detail: _startupErrorMessage ?? 'Workspace setup failed.',
        workspaceLabel: _workspaceStepLabel,
        rendererLabel: _rendererStepLabel,
        workspaceState: _workspaceStepState.name,
        rendererState: _rendererStepState.name,
        audioLabel: _requiresAudioStep ? _audioStepLabel : null,
        audioState: _requiresAudioStep ? _audioStepState.name : null,
        yieldToFlutter: true,
      );
      return;
    }

    publishWorkspaceStartupState(
      title: _startupTitle,
      detail: _startupDetail,
      workspaceLabel: _workspaceStepLabel,
      rendererLabel: _rendererStepLabel,
      workspaceState: _workspaceStepState.name,
      rendererState: _rendererStepState.name,
      audioLabel: _requiresAudioStep ? _audioStepLabel : null,
      audioState: _requiresAudioStep ? _audioStepState.name : null,
    );
  }

  bool get _requiresAudioStep => _mode == WorkspaceMode.rhythmTest;

  String get _startupTitle => switch (_startupPhase) {
    _WorkspaceStartupPhase.preparingWorkspace => 'Preparing workspace',
    _WorkspaceStartupPhase.preparingRenderer =>
      _mode == WorkspaceMode.compose
          ? 'Preparing editor'
          : 'Preparing rhythm test',
    _WorkspaceStartupPhase.preparingRhythmTestAudio => 'Preparing rhythm test',
    _WorkspaceStartupPhase.retryingRhythmTestAudio =>
      'Retrying rhythm test audio',
    _WorkspaceStartupPhase.ready => 'Tap Score is ready',
    _WorkspaceStartupPhase.failed =>
      _startupFailureKind == _WorkspaceStartupFailureKind.rhythmTestAudio
          ? 'Rhythm test unavailable'
          : 'Workspace unavailable',
  };

  String get _startupDetail => switch (_startupPhase) {
    _WorkspaceStartupPhase.preparingWorkspace => _workspaceStepLabel,
    _WorkspaceStartupPhase.preparingRenderer =>
      _mode == WorkspaceMode.compose
          ? 'Loading the score renderer before opening the editor.'
          : 'Loading the rhythm test surface before entering the page.',
    _WorkspaceStartupPhase.preparingRhythmTestAudio => _audioStepLabel,
    _WorkspaceStartupPhase.retryingRhythmTestAudio => _audioStepLabel,
    _WorkspaceStartupPhase.ready => 'Workspace setup finished.',
    _WorkspaceStartupPhase.failed =>
      _startupErrorMessage ?? 'Workspace setup failed.',
  };

  _StartupStepState get _workspaceStepState {
    if (_startupFailed &&
        _startupFailureKind == _WorkspaceStartupFailureKind.workspace) {
      return _StartupStepState.error;
    }
    if (!_workspacePrepared) {
      return _StartupStepState.active;
    }
    return _StartupStepState.complete;
  }

  _StartupStepState get _rendererStepState {
    if (!_workspacePrepared) {
      return _StartupStepState.pending;
    }
    if (_rendererReady) {
      return _StartupStepState.complete;
    }
    if (_startupPhase == _WorkspaceStartupPhase.failed &&
        _startupFailureKind == _WorkspaceStartupFailureKind.workspace) {
      return _StartupStepState.pending;
    }
    return _StartupStepState.active;
  }

  _StartupStepState get _audioStepState {
    if (!_requiresAudioStep || !_workspacePrepared) {
      return _StartupStepState.pending;
    }
    if (_startupFailed &&
        _startupFailureKind == _WorkspaceStartupFailureKind.rhythmTestAudio) {
      return _StartupStepState.error;
    }
    if (_audioReady) {
      return _StartupStepState.complete;
    }
    return _StartupStepState.active;
  }

  Future<void> _retryStartup() async {
    if (_startupFailureKind == _WorkspaceStartupFailureKind.rhythmTestAudio) {
      final notifier = context.read<ScoreNotifier>();
      if (_requiresRhythmTestAudioGate(notifier)) {
        unawaited(_prepareRhythmTestAudio(pass: ++_startupPass, attempt: 1));
        return;
      }
    }

    await _startStartupFlow();
  }

  Future<void> _showSaveDialog() async {
    final notifier = context.read<ScoreNotifier>();
    await showDialog<void>(
      context: context,
      builder: (_) => _SaveScoreDialog(notifier: notifier),
    );
  }

  void _handleRhythmTempoChanged(double bpm) {
    final scoreNotifier = context.read<ScoreNotifier>();
    scoreNotifier.setTempo(bpm);
    _rhythmTestNotifier?.setTempo(bpm);
  }

  Future<void> _exportCurrentScore(BuildContext buttonContext) async {
    final notifier = context.read<ScoreNotifier>();
    final document = notifier.buildPortableDocument();
    final fileName = _buildExportFileName(document.name);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    try {
      await _scoreTransferService.exportDocument(
        document,
        fileName: fileName,
        sharePositionOrigin: origin,
      );
      if (!mounted) {
        return;
      }
      notifier.showLibraryMessage('Exported "$fileName".', isError: false);
    } on ScoreTransferException catch (error) {
      notifier.showLibraryMessage(error.message, isError: true);
    } catch (_) {
      notifier.showLibraryMessage(
        'Failed to export the current score.',
        isError: true,
      );
    }
  }

  String _buildExportFileName(String label) {
    final rawBaseName = label == 'Draft'
        ? 'tap_score_${DateTime.now().toIso8601String()}'
        : label;
    final safeBaseName = rawBaseName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final baseName = safeBaseName.isEmpty ? 'tap_score' : safeBaseName;
    return '$baseName.json';
  }

  bool _handleRendererKeyDown(String? key, String? code, bool repeat) {
    if (!_startupReady) {
      return false;
    }

    if (_mode == WorkspaceMode.compose) {
      if (key == ' ' || code == 'Space') {
        final notifier = context.read<ScoreNotifier>();
        if (notifier.isPlaying) {
          notifier.stop();
        } else {
          notifier.play();
        }
        return true;
      }
      return false;
    }

    if (!repeat && (key == ' ' || code == 'Space')) {
      _rhythmTestNotifier?.performPrimaryAction();
      return true;
    }

    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_startupReady) {
      return KeyEventResult.ignored;
    }

    if (_mode == WorkspaceMode.rhythmTest) {
      if (event is KeyDownEvent) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.space) {
          _rhythmTestNotifier?.performPrimaryAction();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final notifier = context.read<ScoreNotifier>();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (notifier.isPlaying) {
        notifier.stop();
      } else {
        notifier.play();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      notifier.moveSelectionLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      notifier.moveSelectionRight();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      notifier.adjustSelection(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      notifier.adjustSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      notifier.deleteSelected();
      return KeyEventResult.handled;
    }

    final shortcut = resolveEditorShortcutEvent(
      EditorShortcutEvent(logicalKey: key, character: event.character),
      inputMode: notifier.keyboardInputMode,
      octaveShift: notifier.keyboardOctaveShift,
      clef: notifier.score.clef,
    );
    if (shortcut == null) {
      return KeyEventResult.ignored;
    }
    notifier.handleEditorShortcut(shortcut);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _focusNode.requestFocus(),
        child: Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Consumer<ScoreNotifier>(
                  builder: (context, notifier, _) {
                    return Column(
                      children: [
                        WorkspaceTopBar(
                          key: const ValueKey('workspace-top-bar'),
                          mode: _mode,
                          showsEditorActions:
                              _startupReady && _mode == WorkspaceMode.compose,
                          isInteractive: _startupReady,
                          hasUnsavedChanges: notifier.hasUnsavedChanges,
                          onGoHome: widget.onGoHome ?? () {},
                          onSelectMode: _switchMode,
                          onSave: _showSaveDialog,
                          onExport: _exportCurrentScore,
                        ),
                        Expanded(child: _buildWorkspaceBody(notifier)),
                      ],
                    );
                  },
                ),
                if (_showsStartupOverlay)
                  Positioned.fill(
                    child: _WorkspaceStartupView(
                      title: _startupTitle,
                      detail: _startupDetail,
                      workspaceLabel: _workspaceStepLabel,
                      workspaceState: _workspaceStepState,
                      rendererLabel: _rendererStepLabel,
                      rendererState: _rendererStepState,
                      audioLabel: _requiresAudioStep ? _audioStepLabel : null,
                      audioState: _requiresAudioStep ? _audioStepState : null,
                      errorMessage: _startupErrorMessage,
                      onRetry: _startupFailed ? _retryStartup : null,
                      onGoHome: _startupFailed && widget.onGoHome != null
                          ? widget.onGoHome
                          : null,
                    ),
                  ),
                const _LibraryToastLayer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceBody(ScoreNotifier notifier) {
    if (!_workspacePrepared) {
      return const SizedBox.expand();
    }

    if (_mode == WorkspaceMode.compose) {
      return _buildComposeBody(notifier);
    }

    return _buildRhythmTestBody(notifier);
  }

  Widget _buildComposeBody(ScoreNotifier notifier) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _ComposeViewportMetrics.fromSize(constraints.biggest);
        final bodyLayout = metrics.resolveBodyLayout(constraints.maxHeight);

        return Column(
          children: [
            SizedBox(
              height: bodyLayout.scoreHeight,
              child: ScoreViewWidget(
                key: ValueKey('compose-score-view-$_rendererSession'),
                interactive: true,
                onRendererKeyDown: _handleRendererKeyDown,
                onRendererReady: () => _handleRendererReady(_rendererSession),
              ),
            ),
            Container(height: 1, color: AppColors.surfaceDivider),
            if (bodyLayout.composeDockHeight > 0)
              SizedBox(
                height: bodyLayout.composeDockHeight,
                child: _ComposeDock(notifier: notifier, metrics: metrics),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRhythmTestBody(ScoreNotifier notifier) {
    final rhythmTestNotifier = _rhythmTestNotifier;
    if (rhythmTestNotifier == null || notifier.score.notes.isEmpty) {
      return _WorkspaceBodyMessage(
        title: 'Rhythm test unavailable',
        message:
            notifier.libraryMessage ??
            'Rhythm test needs at least one note in the current score.',
      );
    }

    return ChangeNotifierProvider.value(
      value: rhythmTestNotifier,
      child: RhythmTestWorkspace(
        onTempoChanged: _handleRhythmTempoChanged,
        onRendererKeyDown: _handleRendererKeyDown,
        onRendererReady: () => _handleRendererReady(_rendererSession),
      ),
    );
  }
}

class _ComposeDock extends StatelessWidget {
  const _ComposeDock({required this.notifier, required this.metrics});

  final ScoreNotifier notifier;
  final _ComposeViewportMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const ValueKey('compose-toolbar'),
          color: AppColors.surfaceContainer,
          child: _ComposeToolbarLayout(notifier: notifier, metrics: metrics),
        ),
        PianoKeyboard(layout: metrics.keyboardLayout),
      ],
    );
    return SingleChildScrollView(
      key: const ValueKey('compose-dock-scroll-view'),
      child: content,
    );
  }
}

class _ComposeViewportMetrics {
  const _ComposeViewportMetrics({
    required this.preferredScoreMinHeight,
    required this.minimumVisibleScoreHeight,
    required this.preferredToolbarHeight,
    required this.minimumComposeDockViewportHeight,
    required this.toolbarPadding,
    required this.toolbarSectionPadding,
    required this.toolbarSectionGap,
    required this.infoChipSpacing,
    required this.infoChipRunSpacing,
    required this.keyboardLayout,
  });

  static const regular = _ComposeViewportMetrics(
    preferredScoreMinHeight: 280,
    minimumVisibleScoreHeight: 168,
    preferredToolbarHeight: 132,
    minimumComposeDockViewportHeight: 132,
    toolbarPadding: EdgeInsets.fromLTRB(12, 10, 12, 8),
    toolbarSectionPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    toolbarSectionGap: 10,
    infoChipSpacing: 10,
    infoChipRunSpacing: 8,
    keyboardLayout: PianoKeyboardLayout.regular,
  );

  static const compact = _ComposeViewportMetrics(
    preferredScoreMinHeight: 264,
    minimumVisibleScoreHeight: 148,
    preferredToolbarHeight: 108,
    minimumComposeDockViewportHeight: 108,
    toolbarPadding: EdgeInsets.fromLTRB(10, 8, 10, 6),
    toolbarSectionPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    toolbarSectionGap: 8,
    infoChipSpacing: 8,
    infoChipRunSpacing: 6,
    keyboardLayout: PianoKeyboardLayout.compact,
  );

  final double preferredScoreMinHeight;
  final double minimumVisibleScoreHeight;
  final double preferredToolbarHeight;
  final double minimumComposeDockViewportHeight;
  final EdgeInsets toolbarPadding;
  final EdgeInsets toolbarSectionPadding;
  final double toolbarSectionGap;
  final double infoChipSpacing;
  final double infoChipRunSpacing;
  final PianoKeyboardLayout keyboardLayout;

  double get preferredComposeDockHeight =>
      preferredToolbarHeight + keyboardLayout.height;

  _ComposeBodyLayout resolveBodyLayout(double availableHeight) {
    final contentHeight = math.max(availableHeight, 0.0);
    if (contentHeight <= 0) {
      return const _ComposeBodyLayout(scoreHeight: 0, composeDockHeight: 0);
    }

    final dividerHeight = contentHeight > 1 ? 1.0 : 0.0;
    final minDockViewportHeight = math.min(
      minimumComposeDockViewportHeight,
      math.max(contentHeight - dividerHeight, 0.0),
    );
    final maxScoreHeight = math.max(
      contentHeight - minDockViewportHeight - dividerHeight,
      0.0,
    );
    final minScoreHeight = math.min(minimumVisibleScoreHeight, maxScoreHeight);
    final preferredScoreHeight = math.max(
      preferredScoreMinHeight,
      contentHeight - preferredComposeDockHeight - dividerHeight,
    );
    final scoreHeight = preferredScoreHeight.clamp(
      minScoreHeight,
      maxScoreHeight,
    );
    final composeDockHeight = math.max(
      contentHeight - scoreHeight - dividerHeight,
      0.0,
    );

    return _ComposeBodyLayout(
      scoreHeight: scoreHeight,
      composeDockHeight: composeDockHeight,
    );
  }

  static _ComposeViewportMetrics fromSize(Size size) {
    final isCompact = size.width < 900 || size.height < 640;
    return isCompact ? compact : regular;
  }
}

class _ComposeBodyLayout {
  const _ComposeBodyLayout({
    required this.scoreHeight,
    required this.composeDockHeight,
  });

  final double scoreHeight;
  final double composeDockHeight;
}

class _ComposeToolbarLayout extends StatelessWidget {
  const _ComposeToolbarLayout({required this.notifier, required this.metrics});

  final ScoreNotifier notifier;
  final _ComposeViewportMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final playButton = ComposePlayButton(
          key: const ValueKey('compose-play-button'),
          isPlaying: notifier.isPlaying,
          enabled: notifier.score.notes.isNotEmpty,
          onTap: () {
            if (notifier.isPlaying) {
              notifier.stop();
            } else {
              notifier.play();
            }
          },
        );

        final infoChips = ToolbarInfoChips(
          key: const ValueKey('compose-info-chips'),
          beatsPerMeasure: notifier.score.beatsPerMeasure,
          beatUnit: notifier.score.beatUnit,
          keyLabel: notifier.score.keySignature.vexflowKey,
          bpm: notifier.score.bpm,
          tempoEnabled: !notifier.isPlaying,
          spacing: metrics.infoChipSpacing,
          runSpacing: metrics.infoChipRunSpacing,
        );
        final affordanceProfile = resolveInputAffordanceProfile(
          context,
          compact: metrics.keyboardLayout.isCompact,
        );

        final toolbarControls = ToolbarEditStrip(
          compact: metrics.keyboardLayout.isCompact,
          padding: EdgeInsets.zero,
        );
        final isCompact = constraints.maxWidth < 1100;

        return Padding(
          padding: metrics.toolbarPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompact)
                _ToolbarSection(
                  padding: metrics.toolbarSectionPadding,
                  child: Row(
                    children: [
                      playButton,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: infoChips,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    playButton,
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ToolbarSection(
                        padding: metrics.toolbarSectionPadding,
                        child: infoChips,
                      ),
                    ),
                  ],
                ),
              if (notifier.score.notes.isEmpty) ...[
                SizedBox(height: metrics.toolbarSectionGap),
                _ToolbarSection(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.keyboardLayout.isCompact ? 10 : 12,
                    vertical: metrics.keyboardLayout.isCompact ? 6 : 8,
                  ),
                  child: _ComposeGuidanceStrip(
                    message: affordanceProfile.composeEmptyStateGuidance,
                  ),
                ),
              ],
              SizedBox(height: metrics.toolbarSectionGap),
              _ToolbarSection(
                padding: metrics.toolbarSectionPadding,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: toolbarControls,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComposeGuidanceStrip extends StatelessWidget {
  const _ComposeGuidanceStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            key: const ValueKey('compose-empty-guidance'),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolbarSection extends StatelessWidget {
  const _ToolbarSection({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withAlpha(188),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder.withAlpha(160)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SaveScoreDialog extends StatefulWidget {
  const _SaveScoreDialog({required this.notifier});

  final ScoreNotifier notifier;

  @override
  State<_SaveScoreDialog> createState() => _SaveScoreDialogState();
}

class _SaveScoreDialogState extends State<_SaveScoreDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _isSaving = false;

  bool get _hasActiveSavedScore => widget.notifier.activeSavedScore != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.notifier.activeSavedScore?.name ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool createNew}) async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = 'Name is required.';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    await widget.notifier.saveCurrentScore(trimmed, createNew: createNew);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Score'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_isSaving,
        decoration: InputDecoration(labelText: 'Name', errorText: _errorText),
        onSubmitted: _isSaving ? null : (_) => _submit(createNew: false),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_hasActiveSavedScore)
          OutlinedButton(
            onPressed: _isSaving ? null : () => _submit(createNew: true),
            child: const Text('Save As New'),
          ),
        FilledButton(
          onPressed: _isSaving ? null : () => _submit(createNew: false),
          child: Text(_hasActiveSavedScore ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}

class _LibraryToastLayer extends StatelessWidget {
  const _LibraryToastLayer();

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, _) {
        final libraryMessage = notifier.libraryMessage;
        final audioErrorMessage = notifier.audioStatusIsError
            ? notifier.audioStatusMessage
            : null;
        final message = libraryMessage ?? audioErrorMessage;
        final isError = libraryMessage != null
            ? notifier.libraryMessageIsError
            : audioErrorMessage != null;

        return Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide =
                        Tween<Offset>(
                          begin: const Offset(0.1, -0.12),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        );
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: message == null
                      ? const SizedBox.shrink(
                          key: ValueKey('library-toast-empty'),
                        )
                      : _FloatingToast(
                          key: ValueKey('library-toast-$message-$isError'),
                          message: message,
                          isError: isError,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingToast extends StatelessWidget {
  const _FloatingToast({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? AppColors.statusError : AppColors.statusSuccess;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DecoratedBox(
        key: const ValueKey('library-toast'),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withAlpha(245),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withAlpha(110)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textBody,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StartupStepState { pending, active, complete, error }

class _WorkspaceStartupView extends StatelessWidget {
  const _WorkspaceStartupView({
    required this.title,
    required this.detail,
    required this.workspaceLabel,
    required this.workspaceState,
    required this.rendererLabel,
    required this.rendererState,
    this.audioLabel,
    this.audioState,
    this.errorMessage,
    this.onRetry,
    this.onGoHome,
  });

  final String title;
  final String detail;
  final String workspaceLabel;
  final _StartupStepState workspaceState;
  final String rendererLabel;
  final _StartupStepState rendererState;
  final String? audioLabel;
  final _StartupStepState? audioState;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: ColoredBox(
        color: AppColors.surfaceContainer.withAlpha(214),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withAlpha(248),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: errorMessage == null
                        ? AppColors.surfaceBorder
                        : AppColors.statusError.withAlpha(120),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                  child: Column(
                    key: const ValueKey('workspace-startup-card'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        key: const ValueKey('workspace-startup-title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textBody,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        detail,
                        key: const ValueKey('workspace-startup-detail'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: errorMessage == null
                              ? AppColors.textMuted
                              : AppColors.statusError,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _StartupStep(
                        key: const ValueKey('workspace-startup-step-workspace'),
                        label: workspaceLabel,
                        state: workspaceState,
                      ),
                      const SizedBox(height: 12),
                      _StartupStep(
                        key: const ValueKey('workspace-startup-step-renderer'),
                        label: rendererLabel,
                        state: rendererState,
                      ),
                      if (audioLabel != null && audioState != null) ...[
                        const SizedBox(height: 12),
                        _StartupStep(
                          key: const ValueKey('workspace-startup-step-audio'),
                          label: audioLabel!,
                          state: audioState!,
                        ),
                      ],
                      if (errorMessage != null) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            if (onRetry != null)
                              FilledButton(
                                key: const ValueKey('workspace-startup-retry'),
                                onPressed: onRetry,
                                child: const Text('Retry'),
                              ),
                            if (onRetry != null && onGoHome != null)
                              const SizedBox(width: 12),
                            if (onGoHome != null)
                              OutlinedButton(
                                key: const ValueKey(
                                  'workspace-startup-go-home',
                                ),
                                onPressed: onGoHome,
                                child: const Text('Go Home'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupStep extends StatelessWidget {
  const _StartupStep({required this.label, required this.state, super.key});

  final String label;
  final _StartupStepState state;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (state) {
      _StartupStepState.pending => AppColors.textMuted,
      _StartupStepState.active => AppColors.accentBlue,
      _StartupStepState.complete => AppColors.statusSuccess,
      _StartupStepState.error => AppColors.statusError,
    };

    return Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: switch (state) {
            _StartupStepState.pending => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.surfaceBorder, width: 2),
              ),
            ),
            _StartupStepState.active => CircularProgressIndicator(
              strokeWidth: 2.2,
              color: accentColor,
            ),
            _StartupStepState.complete => DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
            _StartupStepState.error => DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: state == _StartupStepState.pending
                  ? AppColors.textMuted
                  : AppColors.textBody,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceBodyMessage extends StatelessWidget {
  const _WorkspaceBodyMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
