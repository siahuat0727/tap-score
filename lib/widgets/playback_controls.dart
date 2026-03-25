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
          child: Column(
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
                  _KeySigChip(label: notifier.score.keySignature.vexflowKey),
                  _TempoChip(
                    bpm: notifier.score.bpm,
                    enabled: !notifier.isPlaying,
                  ),
                  _ActionButton(
                    key: const ValueKey('save-score-button'),
                    icon: Icons.save_outlined,
                    label: 'Save',
                    onTap: onSaveTap,
                  ),
                  _ActionButton(
                    key: const ValueKey('load-score-button'),
                    icon: Icons.folder_open_outlined,
                    label: 'Load',
                    onTap: onLoadTap,
                  ),
                  _ActionButton(
                    key: const ValueKey('export-score-button'),
                    icon: Icons.file_download_outlined,
                    label: 'Export',
                    onTap: () => onExportTap(context),
                  ),
                ],
              ),
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
          ),
        );
      },
    );
  }
}

class _TempoChip extends StatelessWidget {
  const _TempoChip({required this.bpm, required this.enabled});

  final double bpm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => _showTempoSheet(context) : null,
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
            const Icon(Icons.speed, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(
              '♩ = ${bpm.round()}',
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

  void _showTempoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Consumer<ScoreNotifier>(
            builder: (context, notifier, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '♩ = ${notifier.score.bpm.round()}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.sliderActive,
                      inactiveTrackColor: AppColors.sliderInactive,
                      thumbColor: AppColors.sliderActive,
                      overlayColor: AppColors.sliderActive.withAlpha(51),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: notifier.score.bpm,
                      min: 40,
                      max: 240,
                      divisions: 200,
                      label: '${notifier.score.bpm.round()} BPM',
                      onChanged: notifier.setTempo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '40',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '240',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, size: 14, color: AppColors.textMuted),
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
  const _TimeSigChip({required this.beatsPerMeasure, required this.beatUnit});

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
            const Icon(Icons.queue_music, size: 14, color: AppColors.textMuted),
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
