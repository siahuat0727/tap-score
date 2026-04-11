import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/score_seed_config.dart';
import '../app/workspace_launch_config.dart';
import '../input/editor_shortcuts.dart';
import '../services/audio_service.dart';
import '../services/score_transfer_service.dart';
import '../state/rhythm_test_notifier.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/duration_selector.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/playback_controls.dart';
import '../widgets/rhythm_test_workspace.dart';
import '../widgets/score_view_widget.dart';
import '../widgets/workspace_top_bar.dart';

typedef WorkspaceRouteSync =
    void Function(WorkspaceMode mode, String? shareablePresetId);

enum _WorkspaceStartupPhase {
  startingApp,
  preparingWorkspace,
  preparingRhythmTest,
  ready,
  failed,
}

class _WorkspaceStartupStatus {
  const _WorkspaceStartupStatus._(this.phase, {this.errorMessage});

  const _WorkspaceStartupStatus.startingApp()
    : this._(_WorkspaceStartupPhase.startingApp);

  const _WorkspaceStartupStatus.preparingWorkspace()
    : this._(_WorkspaceStartupPhase.preparingWorkspace);

  const _WorkspaceStartupStatus.preparingRhythmTest()
    : this._(_WorkspaceStartupPhase.preparingRhythmTest);

  const _WorkspaceStartupStatus.ready() : this._(_WorkspaceStartupPhase.ready);

  const _WorkspaceStartupStatus.failed(String message)
    : this._(_WorkspaceStartupPhase.failed, errorMessage: message);

  final _WorkspaceStartupPhase phase;
  final String? errorMessage;

  bool get isReady => phase == _WorkspaceStartupPhase.ready;
  bool get isFailed => phase == _WorkspaceStartupPhase.failed;
}

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
  final FocusNode _focusNode = FocusNode();
  late final ScoreTransferService _scoreTransferService =
      widget.scoreTransferService ?? PlatformScoreTransferService();
  late WorkspaceMode _mode = widget.launchConfig.initialMode;
  RhythmTestNotifier? _rhythmTestNotifier;
  _WorkspaceStartupStatus _startupStatus =
      const _WorkspaceStartupStatus.startingApp();

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _startupStatus = const _WorkspaceStartupStatus.preparingWorkspace();
    });

    await context.read<ScoreNotifier>().init(
      initialScoreConfig: widget.launchConfig.seedConfig,
    );
    if (!mounted) {
      return;
    }

    final notifier = context.read<ScoreNotifier>();
    if (!notifier.initialWorkspaceLoadSucceeded) {
      setState(() {
        _startupStatus = _WorkspaceStartupStatus.failed(
          notifier.libraryMessage ?? 'Failed to load the workspace.',
        );
      });
      return;
    }

    if (_mode == WorkspaceMode.rhythmTest) {
      setState(() {
        _startupStatus = const _WorkspaceStartupStatus.preparingRhythmTest();
      });
      await _enterRhythmTest(duringStartup: true);
      if (!mounted) {
        return;
      }
    }

    _syncRoute();
    _focusNode.requestFocus();
    setState(() {
      _startupStatus = const _WorkspaceStartupStatus.ready();
    });
  }

  Future<void> _switchMode(WorkspaceMode nextMode) async {
    if (!_startupStatus.isReady || nextMode == _mode) {
      return;
    }

    if (nextMode == WorkspaceMode.compose) {
      final previousNotifier = _rhythmTestNotifier;
      setState(() {
        _mode = WorkspaceMode.compose;
        _rhythmTestNotifier = null;
      });
      previousNotifier?.dispose();
      _syncRoute();
      _focusNode.requestFocus();
      return;
    }

    await _enterRhythmTest(duringStartup: false);
  }

  Future<void> _enterRhythmTest({required bool duringStartup}) async {
    final scoreNotifier = context.read<ScoreNotifier>();
    scoreNotifier.stop();
    if (scoreNotifier.score.notes.isEmpty) {
      final previousNotifier = _rhythmTestNotifier;
      setState(() {
        _mode = WorkspaceMode.rhythmTest;
        _rhythmTestNotifier = null;
      });
      previousNotifier?.dispose();
      if (!duringStartup) {
        _syncRoute();
        _focusNode.requestFocus();
      }
      return;
    }

    final previousNotifier = _rhythmTestNotifier;
    final rhythmTestNotifier = RhythmTestNotifier(
      score: scoreNotifier.score,
      audioService: widget.rhythmTestAudioService,
    );
    setState(() {
      _mode = WorkspaceMode.rhythmTest;
      _rhythmTestNotifier = rhythmTestNotifier;
    });
    previousNotifier?.dispose();

    await rhythmTestNotifier.init();
    if (!mounted) {
      rhythmTestNotifier.dispose();
      return;
    }

    if (!duringStartup) {
      _syncRoute();
      _focusNode.requestFocus();
    }
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
    if (!_startupStatus.isReady) {
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
    if (!_startupStatus.isReady) {
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
                              _startupStatus.isReady &&
                              _mode == WorkspaceMode.compose,
                          isInteractive: _startupStatus.isReady,
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
                const _LibraryToastLayer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceBody(ScoreNotifier notifier) {
    if (_startupStatus.isFailed) {
      return _WorkspaceUnavailableView(
        title: 'Workspace unavailable',
        message: _startupStatus.errorMessage ?? 'Failed to load the workspace.',
      );
    }

    if (!_startupStatus.isReady) {
      return _WorkspaceStartupView(
        status: _startupStatus,
        launchConfig: widget.launchConfig,
      );
    }

    if (_mode == WorkspaceMode.compose) {
      return _buildComposeBody(notifier);
    }

    return _buildRhythmTestBody(notifier);
  }

  Widget _buildComposeBody(ScoreNotifier notifier) {
    return Column(
      children: [
        Expanded(
          child: ScoreViewWidget(
            interactive: true,
            onRendererKeyDown: _handleRendererKeyDown,
          ),
        ),
        Container(height: 1, color: AppColors.surfaceDivider),
        Container(
          key: const ValueKey('compose-toolbar'),
          color: AppColors.surfaceContainer,
          child: _ComposeToolbarLayout(notifier: notifier),
        ),
        const PianoKeyboard(),
      ],
    );
  }

  Widget _buildRhythmTestBody(ScoreNotifier notifier) {
    final rhythmTestNotifier = _rhythmTestNotifier;
    if (rhythmTestNotifier == null || notifier.score.notes.isEmpty) {
      return _WorkspaceUnavailableView(
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
      ),
    );
  }
}

class _ComposeToolbarLayout extends StatelessWidget {
  const _ComposeToolbarLayout({required this.notifier});

  final ScoreNotifier notifier;

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
        );

        final toolbarControls = const ToolbarEditStrip(
          padding: EdgeInsets.zero,
        );
        final isCompact = constraints.maxWidth < 1100;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompact)
                _ToolbarSection(
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
                    Expanded(child: _ToolbarSection(child: infoChips)),
                  ],
                ),
              const SizedBox(height: 10),
              _ToolbarSection(
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

class _ToolbarSection extends StatelessWidget {
  const _ToolbarSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withAlpha(188),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder.withAlpha(160)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: child,
      ),
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

enum _StartupStepState { pending, active, complete }

class _WorkspaceStartupView extends StatelessWidget {
  const _WorkspaceStartupView({
    required this.status,
    required this.launchConfig,
  });

  final _WorkspaceStartupStatus status;
  final WorkspaceLaunchConfig launchConfig;

  String get _title => switch (status.phase) {
    _WorkspaceStartupPhase.startingApp => 'Starting app',
    _WorkspaceStartupPhase.preparingWorkspace => 'Preparing workspace',
    _WorkspaceStartupPhase.preparingRhythmTest => 'Preparing rhythm test',
    _WorkspaceStartupPhase.ready || _WorkspaceStartupPhase.failed =>
      throw StateError('Startup card only renders while work is in progress.'),
  };

  String get _detail => switch (status.phase) {
    _WorkspaceStartupPhase.startingApp =>
      'Tap Score is starting the app shell.',
    _WorkspaceStartupPhase.preparingWorkspace => _workspaceStepLabel,
    _WorkspaceStartupPhase.preparingRhythmTest =>
      'Loading rhythm test audio and controls.',
    _WorkspaceStartupPhase.ready || _WorkspaceStartupPhase.failed =>
      throw StateError('Startup card only renders while work is in progress.'),
  };

  String get _workspaceStepLabel => switch (launchConfig.seedConfig.kind) {
    ScoreSeedKind.restore => 'Restoring last workspace',
    ScoreSeedKind.blank => 'Creating empty workspace',
    ScoreSeedKind.preset => 'Loading preset',
    ScoreSeedKind.saved => 'Loading saved score',
    ScoreSeedKind.imported => 'Importing score',
  };

  _StartupStepState get _appStepState => switch (status.phase) {
    _WorkspaceStartupPhase.startingApp => _StartupStepState.active,
    _WorkspaceStartupPhase.preparingWorkspace ||
    _WorkspaceStartupPhase.preparingRhythmTest => _StartupStepState.complete,
    _WorkspaceStartupPhase.ready || _WorkspaceStartupPhase.failed =>
      throw StateError('Startup card only renders while work is in progress.'),
  };

  _StartupStepState get _workspaceStepState => switch (status.phase) {
    _WorkspaceStartupPhase.startingApp => _StartupStepState.pending,
    _WorkspaceStartupPhase.preparingWorkspace => _StartupStepState.active,
    _WorkspaceStartupPhase.preparingRhythmTest => _StartupStepState.complete,
    _WorkspaceStartupPhase.ready || _WorkspaceStartupPhase.failed =>
      throw StateError('Startup card only renders while work is in progress.'),
  };

  _StartupStepState get _rhythmStepState => switch (status.phase) {
    _WorkspaceStartupPhase.startingApp ||
    _WorkspaceStartupPhase.preparingWorkspace => _StartupStepState.pending,
    _WorkspaceStartupPhase.preparingRhythmTest => _StartupStepState.active,
    _WorkspaceStartupPhase.ready || _WorkspaceStartupPhase.failed =>
      throw StateError('Startup card only renders while work is in progress.'),
  };

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 20,
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
                  _title,
                  key: const ValueKey('workspace-startup-title'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _detail,
                  key: const ValueKey('workspace-startup-detail'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                _StartupStep(
                  key: const ValueKey('workspace-startup-step-app'),
                  label: status.phase == _WorkspaceStartupPhase.startingApp
                      ? 'Starting app'
                      : 'App shell ready',
                  state: _appStepState,
                ),
                const SizedBox(height: 12),
                _StartupStep(
                  key: const ValueKey('workspace-startup-step-workspace'),
                  label: _workspaceStepLabel,
                  state: _workspaceStepState,
                ),
                if (launchConfig.initialMode == WorkspaceMode.rhythmTest) ...[
                  const SizedBox(height: 12),
                  _StartupStep(
                    key: const ValueKey('workspace-startup-step-rhythm-test'),
                    label: 'Preparing rhythm test',
                    state: _rhythmStepState,
                  ),
                ],
              ],
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

class _WorkspaceUnavailableView extends StatelessWidget {
  const _WorkspaceUnavailableView({required this.title, required this.message});

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
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
