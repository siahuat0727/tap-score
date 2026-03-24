import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import 'signature_pickers.dart';

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
                            _TimeSigChip(
                              beatsPerMeasure: notifier.score.beatsPerMeasure,
                              beatUnit: notifier.score.beatUnit,
                            ),
                            _KeySigChip(
                              label: notifier.score.keySignature.vexflowKey,
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
                            Flexible(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _ScoreChip(
                                    label: notifier.currentScoreLabel,
                                    hasUnsavedChanges:
                                        notifier.hasUnsavedChanges,
                                  ),
                                  _TimeSigChip(
                                    beatsPerMeasure:
                                        notifier.score.beatsPerMeasure,
                                    beatUnit: notifier.score.beatUnit,
                                  ),
                                  _KeySigChip(
                                    label:
                                        notifier.score.keySignature.vexflowKey,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
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
            color: AppColors.textMedium,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.sliderActive,
              inactiveTrackColor: AppColors.sliderInactive,
              thumbColor: AppColors.sliderActive,
              overlayColor: AppColors.sliderActive.withAlpha(51),
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
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
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
                color: AppColors.textChip,
              ),
            ),
            if (hasUnsavedChanges) ...[
              const SizedBox(width: 8),
              const Icon(Icons.circle, size: 8, color: AppColors.accentAmber),
              const SizedBox(width: 4),
              const Text(
                'Unsaved',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentAmber,
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
    final color = isError ? AppColors.statusError : AppColors.statusSuccess;
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

class _TimeSigChip extends StatelessWidget {
  const _TimeSigChip({
    required this.beatsPerMeasure,
    required this.beatUnit,
  });

  final int beatsPerMeasure;
  final int beatUnit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showTimeSigPicker(context, context.read<ScoreNotifier>());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              '$beatsPerMeasure/$beatUnit',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textChip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeySigChip extends StatelessWidget {
  const _KeySigChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showKeySigPicker(context, context.read<ScoreNotifier>());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.queue_music,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textChip,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                  ? [AppColors.stopGradientStart, AppColors.stopGradientEnd]
                  : widget.enabled
                  ? [AppColors.playGradientStart, AppColors.playGradientEnd]
                  : [AppColors.playDisabledStart, AppColors.playDisabledEnd],
            ),
            boxShadow: [
              BoxShadow(
                color:
                    (widget.isPlaying
                            ? AppColors.stopGradientStart
                            : AppColors.playGradientStart)
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
