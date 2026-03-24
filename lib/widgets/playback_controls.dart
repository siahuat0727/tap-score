import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/score_notifier.dart';

/// Playback control bar with play/stop, save/load, and tempo controls.
class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    required this.onSaveTap,
    required this.onLoadTap,
    required this.onExportTap,
    super.key,
  });

  final VoidCallback onSaveTap;
  final VoidCallback onLoadTap;
  final ValueChanged<BuildContext> onExportTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final toolbar = compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _PlayButton(
                              isPlaying: notifier.isPlaying,
                              onTap: () {
                                if (notifier.isPlaying) {
                                  notifier.stop();
                                } else {
                                  notifier.play();
                                }
                              },
                              enabled: notifier.score.notes.isNotEmpty,
                            ),
                            _ScoreChip(
                              label: notifier.currentScoreLabel,
                              hasUnsavedChanges: notifier.hasUnsavedChanges,
                            ),
                            FilledButton.icon(
                              key: const ValueKey('save-score-button'),
                              onPressed: onSaveTap,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('load-score-button'),
                              onPressed: onLoadTap,
                              icon: const Icon(Icons.folder_open_outlined),
                              label: const Text('Load'),
                            ),
                            Builder(
                              builder: (buttonContext) {
                                return OutlinedButton.icon(
                                  key: const ValueKey('export-score-button'),
                                  onPressed: () => onExportTap(buttonContext),
                                  icon: const Icon(
                                    Icons.file_download_outlined,
                                  ),
                                  label: const Text('Export'),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _TempoStrip(
                          bpm: notifier.score.bpm,
                          enabled: !notifier.isPlaying,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _PlayButton(
                              isPlaying: notifier.isPlaying,
                              onTap: () {
                                if (notifier.isPlaying) {
                                  notifier.stop();
                                } else {
                                  notifier.play();
                                }
                              },
                              enabled: notifier.score.notes.isNotEmpty,
                            ),
                            const SizedBox(width: 14),
                            _ScoreChip(
                              label: notifier.currentScoreLabel,
                              hasUnsavedChanges: notifier.hasUnsavedChanges,
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              key: const ValueKey('save-score-button'),
                              onPressed: onSaveTap,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              key: const ValueKey('load-score-button'),
                              onPressed: onLoadTap,
                              icon: const Icon(Icons.folder_open_outlined),
                              label: const Text('Load'),
                            ),
                            const SizedBox(width: 8),
                            Builder(
                              builder: (buttonContext) {
                                return OutlinedButton.icon(
                                  key: const ValueKey('export-score-button'),
                                  onPressed: () => onExportTap(buttonContext),
                                  icon: const Icon(
                                    Icons.file_download_outlined,
                                  ),
                                  label: const Text('Export'),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _TempoStrip(
                          bpm: notifier.score.bpm,
                          enabled: !notifier.isPlaying,
                        ),
                      ],
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  toolbar,
                  if (notifier.audioStatusMessage != null) ...[
                    const SizedBox(height: 10),
                    _LibraryMessage(
                      message: notifier.audioStatusMessage!,
                      isError: notifier.audioStatusIsError,
                    ),
                  ],
                  if (notifier.libraryMessage != null) ...[
                    const SizedBox(height: 10),
                    _LibraryMessage(
                      message: notifier.libraryMessage!,
                      isError: notifier.libraryMessageIsError,
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TempoStrip extends StatelessWidget {
  const _TempoStrip({required this.bpm, required this.enabled});

  final double bpm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '♩ = ${bpm.round()}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF444444),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2196F3),
              inactiveTrackColor: const Color(0xFFE0E0E0),
              thumbColor: const Color(0xFF2196F3),
              overlayColor: const Color(0xFF2196F3).withAlpha(51),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Consumer<ScoreNotifier>(
              builder: (context, notifier, _) {
                return Slider(
                  value: notifier.score.bpm,
                  min: 40,
                  max: 240,
                  divisions: 200,
                  label: '${notifier.score.bpm.round()} BPM',
                  onChanged: enabled ? notifier.setTempo : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.hasUnsavedChanges});

  final String label;
  final bool hasUnsavedChanges;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0D6C4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF4E473A),
              ),
            ),
            if (hasUnsavedChanges) ...[
              const SizedBox(width: 8),
              const Icon(Icons.circle, size: 8, color: Color(0xFFD97706)),
              const SizedBox(width: 4),
              const Text(
                'Unsaved',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFC62828) : const Color(0xFF1E8E5A);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          message,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.onTap,
    required this.enabled,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        if (widget.enabled) widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isPlaying
                  ? [const Color(0xFFF44336), const Color(0xFFD32F2F)]
                  : widget.enabled
                  ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
                  : [const Color(0xFFBDBDBD), const Color(0xFF9E9E9E)],
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (widget.isPlaying
                            ? const Color(0xFFF44336)
                            : const Color(0xFF4CAF50))
                        .withAlpha(widget.enabled ? 102 : 0),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
