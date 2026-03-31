import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/practice_launch_config.dart';
import '../services/preset_score_repository.dart';
import '../state/rhythm_test_notifier.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/preset_picker_dialog.dart';
import '../widgets/rhythm_test_workspace.dart';
import '../widgets/workspace_top_bar.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    required this.launchConfig,
    required this.onGoHome,
    required this.onChoosePreset,
    required this.onOpenInEditor,
    this.presetScoreRepository,
    super.key,
  });

  final PracticeLaunchConfig launchConfig;
  final PresetScoreRepository? presetScoreRepository;
  final VoidCallback onGoHome;
  final ValueChanged<String> onChoosePreset;
  final ValueChanged<String> onOpenInEditor;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final FocusNode _focusNode = FocusNode();
  RhythmTestNotifier? _rhythmTestNotifier;
  late final Future<void> _initFuture = _initPractice();

  @override
  void dispose() {
    _rhythmTestNotifier?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initPractice() async {
    final scoreNotifier = context.read<ScoreNotifier>();
    await scoreNotifier.init(
      initialScoreConfig: widget.launchConfig.seedConfig,
    );
    if (!mounted || scoreNotifier.score.notes.isEmpty) {
      return;
    }

    final rhythmNotifier = RhythmTestNotifier(score: scoreNotifier.score);
    _rhythmTestNotifier = rhythmNotifier;
    await rhythmNotifier.init();
    if (!mounted) {
      rhythmNotifier.dispose();
      _rhythmTestNotifier = null;
      return;
    }
    setState(() {});
    _focusNode.requestFocus();
  }

  void _handleRhythmTempoChanged(double bpm) {
    final scoreNotifier = context.read<ScoreNotifier>();
    scoreNotifier.setTempo(bpm);
    _rhythmTestNotifier?.setTempo(bpm);
  }

  bool _handleRendererKeyDown(String? key, String? code) {
    if (key == 'Enter' || code == 'Enter' || code == 'NumpadEnter') {
      _rhythmTestNotifier?.recordTap();
      return true;
    }
    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _rhythmTestNotifier?.recordTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showPresetPicker() {
    return showPresetPickerDialog(
      context: context,
      presetScoreRepository: widget.presetScoreRepository,
      subtitle: 'Choose a preset to start the rhythm test',
      onSelected: widget.onChoosePreset,
    );
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
            child: Consumer<ScoreNotifier>(
              builder: (context, notifier, _) {
                return Column(
                  children: [
                    WorkspaceTopBar(
                      key: const ValueKey('practice-top-bar'),
                      title: 'Rhythm Test',
                      subtitle: notifier.currentScoreLabel,
                      leadingActions: [
                        WorkspaceTopBarAction(
                          buttonKey: const ValueKey('practice-home-button'),
                          label: 'Home',
                          icon: Icons.home_outlined,
                          onTap: widget.onGoHome,
                        ),
                        WorkspaceTopBarAction(
                          buttonKey: const ValueKey(
                            'practice-choose-preset-button',
                          ),
                          label: 'Choose Another Preset',
                          icon: Icons.library_music_outlined,
                          onTap: () {
                            _showPresetPicker();
                          },
                        ),
                      ],
                      trailingAction: WorkspaceTopBarAction(
                        buttonKey: const ValueKey(
                          'practice-open-in-editor-button',
                        ),
                        label: 'Open in Editor',
                        icon: Icons.edit_outlined,
                        onTap: () =>
                            widget.onOpenInEditor(widget.launchConfig.presetId),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<void>(
                        future: _initFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const _PracticeLoadingView();
                          }

                          if (_rhythmTestNotifier == null ||
                              notifier.score.notes.isEmpty) {
                            return _PracticeUnavailableView(
                              message:
                                  notifier.libraryMessage ??
                                  'This preset could not be opened for practice.',
                            );
                          }

                          return ChangeNotifierProvider.value(
                            value: _rhythmTestNotifier!,
                            child: RhythmTestWorkspace(
                              onTempoChanged: _handleRhythmTempoChanged,
                              onRendererKeyDown: _handleRendererKeyDown,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeLoadingView extends StatelessWidget {
  const _PracticeLoadingView();

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

class _PracticeUnavailableView extends StatelessWidget {
  const _PracticeUnavailableView({required this.message});

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
                const Text(
                  'Practice unavailable',
                  style: TextStyle(
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
