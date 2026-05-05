import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/app_shell_ready_bridge.dart';
import '../app/workspace_launch_config.dart';
import '../input/editor_shortcuts.dart';
import '../services/audio_service.dart';
import '../services/score_transfer_service.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import '../workspace/workspace_layout_profile.dart';
import '../workspace/workspace_startup_controller.dart';
import '../widgets/duration_selector.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/playback_controls.dart';
import '../widgets/rhythm_test_workspace.dart';
import '../widgets/score_view_widget.dart';
import '../widgets/workspace_top_bar.dart';

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
  late WorkspaceStartupController _startupController;
  bool _hasStartupController = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_startupController.start());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStartupController) {
      return;
    }
    _startupController = WorkspaceStartupController(
      scoreNotifier: context.read<ScoreNotifier>(),
      launchConfig: widget.launchConfig,
      requestFocus: _focusNode.requestFocus,
      onRouteSync: widget.onRouteSync,
      rhythmTestAudioService: widget.rhythmTestAudioService,
    );
    _startupController.addListener(_handleStartupChanged);
    _hasStartupController = true;
    _publishBrowserStartupState(_startupController.state);
  }

  @override
  void dispose() {
    if (_hasStartupController) {
      _startupController.removeListener(_handleStartupChanged);
      _startupController.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _handleStartupChanged() {
    if (!mounted) {
      return;
    }
    _publishBrowserStartupState(_startupController.state);
    setState(() {});
  }

  Future<void> _switchMode(WorkspaceMode nextMode) {
    return _startupController.switchMode(nextMode);
  }

  void _handleRendererReady(int rendererSession) {
    _startupController.markRendererReady(rendererSession);
  }

  Future<void> _retryStartup() {
    return _startupController.retry();
  }

  void _publishBrowserStartupState(WorkspaceStartupState startupState) {
    if (startupState.ready) {
      publishWorkspaceStartupState(
        title: startupState.title,
        detail: startupState.detail,
        workspaceLabel: startupState.workspaceLabel,
        rendererLabel: startupState.rendererLabel,
        workspaceState: 'complete',
        rendererState: 'complete',
        audioLabel: startupState.requiresAudioStep
            ? startupState.audioLabel
            : null,
        audioState: startupState.requiresAudioStep ? 'complete' : null,
        dismissBootstrap: true,
      );
      return;
    }

    if (startupState.failed) {
      publishWorkspaceStartupState(
        title: startupState.title,
        detail: startupState.detail,
        workspaceLabel: startupState.workspaceLabel,
        rendererLabel: startupState.rendererLabel,
        workspaceState: startupState.workspaceStepState.name,
        rendererState: startupState.rendererStepState.name,
        audioLabel: startupState.requiresAudioStep
            ? startupState.audioLabel
            : null,
        audioState: startupState.requiresAudioStep
            ? startupState.audioStepState.name
            : null,
        yieldToFlutter: true,
      );
      return;
    }

    publishWorkspaceStartupState(
      title: startupState.title,
      detail: startupState.detail,
      workspaceLabel: startupState.workspaceLabel,
      rendererLabel: startupState.rendererLabel,
      workspaceState: startupState.workspaceStepState.name,
      rendererState: startupState.rendererStepState.name,
      audioLabel: startupState.requiresAudioStep
          ? startupState.audioLabel
          : null,
      audioState: startupState.requiresAudioStep
          ? startupState.audioStepState.name
          : null,
    );
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
    _startupController.rhythmTestNotifier?.setTempo(bpm);
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
    final startupState = _startupController.state;
    if (!startupState.ready) {
      return false;
    }

    if (startupState.mode == WorkspaceMode.compose) {
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
      _startupController.rhythmTestNotifier?.performPrimaryAction();
      return true;
    }

    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final startupState = _startupController.state;
    if (!startupState.ready) {
      return KeyEventResult.ignored;
    }

    if (startupState.mode == WorkspaceMode.rhythmTest) {
      if (event is KeyDownEvent) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.space) {
          _startupController.rhythmTestNotifier?.performPrimaryAction();
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
    final startupState = _startupController.state;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _focusNode.requestFocus(),
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layoutProfile = WorkspaceLayoutProfile.fromSize(
                  constraints.biggest,
                );
                return Stack(
                  children: [
                    Consumer<ScoreNotifier>(
                      builder: (context, notifier, _) {
                        return Column(
                          children: [
                            WorkspaceTopBar(
                              key: const ValueKey('workspace-top-bar'),
                              mode: startupState.mode,
                              layoutProfile: layoutProfile,
                              showsEditorActions:
                                  startupState.ready &&
                                  startupState.mode == WorkspaceMode.compose,
                              isInteractive: startupState.ready,
                              hasUnsavedChanges: notifier.hasUnsavedChanges,
                              onGoHome: widget.onGoHome ?? () {},
                              onSelectMode: _switchMode,
                              onSave: _showSaveDialog,
                              onExport: _exportCurrentScore,
                            ),
                            Expanded(
                              child: _buildWorkspaceBody(
                                notifier,
                                layoutProfile,
                                startupState,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (startupState.showsOverlay)
                      Positioned.fill(
                        child: _WorkspaceStartupView(
                          title: startupState.title,
                          detail: startupState.detail,
                          workspaceLabel: startupState.workspaceLabel,
                          workspaceState: startupState.workspaceStepState,
                          rendererLabel: startupState.rendererLabel,
                          rendererState: startupState.rendererStepState,
                          audioLabel: startupState.requiresAudioStep
                              ? startupState.audioLabel
                              : null,
                          audioState: startupState.requiresAudioStep
                              ? startupState.audioStepState
                              : null,
                          errorMessage: startupState.errorMessage,
                          onRetry: startupState.failed ? _retryStartup : null,
                          onGoHome:
                              startupState.failed && widget.onGoHome != null
                              ? widget.onGoHome
                              : null,
                        ),
                      ),
                    const _LibraryToastLayer(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceBody(
    ScoreNotifier notifier,
    WorkspaceLayoutProfile layoutProfile,
    WorkspaceStartupState startupState,
  ) {
    if (!startupState.workspacePrepared) {
      return const SizedBox.expand();
    }

    if (startupState.mode == WorkspaceMode.compose) {
      return _buildComposeBody(notifier, layoutProfile, startupState);
    }

    return _buildRhythmTestBody(notifier, layoutProfile, startupState);
  }

  Widget _buildComposeBody(
    ScoreNotifier notifier,
    WorkspaceLayoutProfile layoutProfile,
    WorkspaceStartupState startupState,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = layoutProfile.composeMetrics;
        final bodyLayout = metrics.resolveBodyLayout(constraints.maxHeight);

        return Column(
          children: [
            SizedBox(
              height: bodyLayout.scoreHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ScoreViewWidget(
                      key: ValueKey(
                        'compose-score-view-${startupState.rendererSession}',
                      ),
                      interactive: true,
                      onRendererKeyDown: _handleRendererKeyDown,
                      onRendererReady: () =>
                          _handleRendererReady(startupState.rendererSession),
                    ),
                  ),
                  if (notifier.score.notes.isEmpty)
                    const Positioned.fill(child: _ComposeEmptySurfaceOverlay()),
                ],
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

  Widget _buildRhythmTestBody(
    ScoreNotifier notifier,
    WorkspaceLayoutProfile layoutProfile,
    WorkspaceStartupState startupState,
  ) {
    final rhythmTestNotifier = _startupController.rhythmTestNotifier;
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
        layoutProfile: layoutProfile,
        onTempoChanged: _handleRhythmTempoChanged,
        onRendererKeyDown: _handleRendererKeyDown,
        onRendererReady: () =>
            _handleRendererReady(startupState.rendererSession),
      ),
    );
  }
}

class _ComposeDock extends StatelessWidget {
  const _ComposeDock({required this.notifier, required this.metrics});

  final ScoreNotifier notifier;
  final WorkspaceComposeMetrics metrics;

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

class _ComposeToolbarLayout extends StatelessWidget {
  const _ComposeToolbarLayout({required this.notifier, required this.metrics});

  final ScoreNotifier notifier;
  final WorkspaceComposeMetrics metrics;

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
        final toolbarControls = ToolbarEditStrip(
          compact: metrics.keyboardLayout.isCompact,
          padding: EdgeInsets.zero,
        );
        final usesCompactHeader = metrics.toolbarUsesCompactHeader;

        return Padding(
          padding: metrics.toolbarPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (usesCompactHeader)
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

class _ComposeEmptySurfaceOverlay extends StatelessWidget {
  const _ComposeEmptySurfaceOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 180;

        return IgnorePointer(
          ignoring: true,
          child: Align(
            alignment: const Alignment(0, 0.6),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 32,
                compact ? 8 : 16,
                compact ? 16 : 32,
                compact ? 12 : 36,
              ),
              child: ConstrainedBox(
                key: const ValueKey('compose-empty-overlay'),
                constraints: const BoxConstraints(maxWidth: 420),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withAlpha(232),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 18,
                      compact ? 12 : 16,
                      compact ? 14 : 18,
                      compact ? 12 : 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ComposeEmptyStep(
                          number: '1',
                          title: 'Choose a duration',
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        _ComposeEmptyStep(
                          number: '2',
                          title: 'Tap the piano',
                          compact: compact,
                        ),
                      ],
                    ),
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

class _ComposeEmptyStep extends StatelessWidget {
  const _ComposeEmptyStep({
    required this.number,
    required this.title,
    required this.compact,
  });

  final String number;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 20 : 24,
          height: compact ? 20 : 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withAlpha(24),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.textBody,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w800,
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
  final WorkspaceStartupStepState workspaceState;
  final String rendererLabel;
  final WorkspaceStartupStepState rendererState;
  final String? audioLabel;
  final WorkspaceStartupStepState? audioState;
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
  final WorkspaceStartupStepState state;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (state) {
      WorkspaceStartupStepState.pending => AppColors.textMuted,
      WorkspaceStartupStepState.active => AppColors.accentBlue,
      WorkspaceStartupStepState.complete => AppColors.statusSuccess,
      WorkspaceStartupStepState.error => AppColors.statusError,
    };

    return Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: switch (state) {
            WorkspaceStartupStepState.pending => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.surfaceBorder, width: 2),
              ),
            ),
            WorkspaceStartupStepState.active => CircularProgressIndicator(
              strokeWidth: 2.2,
              color: accentColor,
            ),
            WorkspaceStartupStepState.complete => DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            ),
            WorkspaceStartupStepState.error => DecoratedBox(
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
              color: state == WorkspaceStartupStepState.pending
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
