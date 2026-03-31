import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/workspace_launch_config.dart';
import '../input/editor_shortcuts.dart';
import '../models/score_library.dart';
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

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    this.launchConfig = const WorkspaceLaunchConfig.blank(),
    this.scoreTransferService,
    this.onGoHome,
    this.onRouteSync,
    super.key,
  });

  final WorkspaceLaunchConfig launchConfig;
  final ScoreTransferService? scoreTransferService;
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
  late final Future<void> _initializationFuture = _initializeWorkspace();
  RhythmTestNotifier? _rhythmTestNotifier;
  bool _workspaceInitialized = false;

  @override
  void dispose() {
    _rhythmTestNotifier?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeWorkspace() async {
    await context.read<ScoreNotifier>().init(
      initialScoreConfig: widget.launchConfig.seedConfig,
    );
    if (!mounted) {
      return;
    }

    _workspaceInitialized = true;
    if (_mode == WorkspaceMode.rhythmTest) {
      await _enterRhythmTest();
      return;
    }

    _syncRoute();
    setState(() {});
    _focusNode.requestFocus();
  }

  Future<void> _switchMode(WorkspaceMode nextMode) async {
    if (nextMode == _mode) {
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

    await _enterRhythmTest();
  }

  Future<void> _enterRhythmTest() async {
    final scoreNotifier = context.read<ScoreNotifier>();
    if (scoreNotifier.score.notes.isEmpty) {
      return;
    }

    scoreNotifier.stop();
    final previousNotifier = _rhythmTestNotifier;
    final rhythmTestNotifier = RhythmTestNotifier(score: scoreNotifier.score);
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

    _syncRoute();
    _focusNode.requestFocus();
  }

  Future<void> _refreshWorkspaceAfterScoreChange() async {
    if (_mode == WorkspaceMode.rhythmTest) {
      final scoreNotifier = context.read<ScoreNotifier>();
      if (scoreNotifier.score.notes.isEmpty) {
        final previousNotifier = _rhythmTestNotifier;
        setState(() {
          _rhythmTestNotifier = null;
        });
        previousNotifier?.dispose();
        _syncRoute();
        return;
      }
      await _enterRhythmTest();
      return;
    }

    _syncRoute();
    _focusNode.requestFocus();
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

  Future<bool> _confirmLoad(String scoreName) async {
    final notifier = context.read<ScoreNotifier>();
    if (!notifier.hasUnsavedChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Load Score?'),
          content: Text(
            'Current edits stay available in Draft. Load "$scoreName" now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Load'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _confirmDeleteSavedScore(String scoreName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Saved Score?'),
          content: Text(
            '"$scoreName" will be removed from the local score library.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showLoadSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Consumer<ScoreNotifier>(
            builder: (context, notifier, _) {
              final items = <_LoadSheetItem>[
                for (final entry in notifier.presetScores)
                  _LoadSheetItem.preset(entry),
                for (final entry in notifier.savedScores)
                  _LoadSheetItem.saved(entry),
              ];

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Scores',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('import-score-button'),
                          onPressed: () async {
                            try {
                              final document = await _scoreTransferService
                                  .importDocument();
                              if (document == null) {
                                return;
                              }
                              final confirmed = await _confirmLoad(
                                document.name,
                              );
                              if (!confirmed || !mounted || !sheetContext.mounted) {
                                return;
                              }
                              Navigator.of(sheetContext).pop();
                              await notifier.importScoreDocument(document);
                              await _refreshWorkspaceAfterScoreChange();
                            } on ScoreTransferException catch (error) {
                              notifier.showLibraryMessage(
                                error.message,
                                isError: true,
                              );
                            } catch (_) {
                              notifier.showLibraryMessage(
                                'Failed to import the selected score document.',
                                isError: true,
                              );
                            }
                          },
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Import'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'No scores available.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isActive =
                                item.source == _LoadSheetItemSource.preset
                                ? item.presetEntry!.id ==
                                      notifier.activePresetId
                                : item.savedEntry!.id == notifier.activeScoreId;

                            return ListTile(
                              key: ValueKey(
                                '${item.source.name}-score-${item.id}',
                              ),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                item.source == _LoadSheetItemSource.preset
                                    ? Icons.library_music_outlined
                                    : Icons.save_outlined,
                                color: AppColors.textMuted,
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle:
                                  item.source == _LoadSheetItemSource.saved
                                  ? Text(
                                      'Updated ${item.savedEntry!.updatedAt.toLocal()}',
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  : const Text(
                                      'Preset score',
                                      style: TextStyle(fontSize: 12),
                                    ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isActive)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Text(
                                        'Current',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.accentAmber,
                                        ),
                                      ),
                                    ),
                                  if (item.source == _LoadSheetItemSource.saved)
                                    IconButton(
                                      tooltip:
                                          'Delete ${item.savedEntry!.name}',
                                      onPressed: () async {
                                        final confirmed =
                                            await _confirmDeleteSavedScore(
                                              item.savedEntry!.name,
                                            );
                                        if (!confirmed) {
                                          return;
                                        }
                                        await notifier.deleteSavedScore(
                                          item.savedEntry!.id,
                                        );
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                ],
                              ),
                              onTap: () async {
                                final confirmed = await _confirmLoad(item.name);
                                if (!confirmed || !mounted || !sheetContext.mounted) {
                                  return;
                                }
                                Navigator.of(sheetContext).pop();
                                if (item.source == _LoadSheetItemSource.preset) {
                                  await notifier.loadPresetScore(
                                    item.presetEntry!.id,
                                  );
                                } else {
                                  await notifier.loadSavedScore(
                                    item.savedEntry!.id,
                                  );
                                }
                                await _refreshWorkspaceAfterScoreChange();
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
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

  bool _handleRendererKeyDown(String? key, String? code) {
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

    if (key == 'Enter' || code == 'Enter' || code == 'NumpadEnter') {
      _rhythmTestNotifier?.recordTap();
      return true;
    }

    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_mode == WorkspaceMode.rhythmTest) {
      if (event is KeyDownEvent) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          _rhythmTestNotifier?.recordTap();
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
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, _) {
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
                              scoreLabel: notifier.currentScoreLabel,
                              mode: _mode,
                              rhythmTestEnabled:
                                  notifier.score.notes.isNotEmpty ||
                                  _mode == WorkspaceMode.rhythmTest,
                              hasUnsavedChanges: notifier.hasUnsavedChanges,
                              onGoHome: widget.onGoHome ?? () {},
                              onSelectMode: _switchMode,
                              onLoad: _showLoadSheet,
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
      },
    );
  }

  Widget _buildWorkspaceBody(ScoreNotifier notifier) {
    if (_mode == WorkspaceMode.compose) {
      return _buildComposeBody(notifier);
    }

    if (!_workspaceInitialized && _rhythmTestNotifier == null) {
      return const _WorkspaceLoadingView();
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

        final toolbarControls = const ToolbarEditStrip(padding: EdgeInsets.zero);
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

enum _LoadSheetItemSource { preset, saved }

class _LoadSheetItem {
  const _LoadSheetItem.preset(this.presetEntry)
    : savedEntry = null,
      source = _LoadSheetItemSource.preset;

  const _LoadSheetItem.saved(this.savedEntry)
    : presetEntry = null,
      source = _LoadSheetItemSource.saved;

  final _LoadSheetItemSource source;
  final PresetScoreEntry? presetEntry;
  final SavedScoreEntry? savedEntry;

  String get id => presetEntry?.id ?? savedEntry!.id;

  String get name => presetEntry?.name ?? savedEntry!.name;
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

class _WorkspaceLoadingView extends StatelessWidget {
  const _WorkspaceLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(strokeWidth: 2.8),
      ),
    );
  }
}

class _WorkspaceUnavailableView extends StatelessWidget {
  const _WorkspaceUnavailableView({
    required this.title,
    required this.message,
  });

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
