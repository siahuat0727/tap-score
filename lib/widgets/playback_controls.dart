import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import 'signature_pickers.dart';

class EditorActionBar extends StatelessWidget {
  const EditorActionBar({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          final actionsWidth = isCompact
              ? constraints.maxWidth
              : constraints.maxWidth * 0.74;
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer.withAlpha(230),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: SizedBox(
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: actionsWidth),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
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
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ComposeTempoChip extends StatelessWidget {
  const ComposeTempoChip({required this.bpm, required this.enabled, super.key});

  final double bpm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _CapsuleButton(
      onTap: enabled ? () => _showTempoSheet(context) : null,
      icon: Icons.speed_rounded,
      label: '♩ = ${bpm.round()}',
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

class ComposePlayButton extends StatefulWidget {
  const ComposePlayButton({
    required this.isPlaying,
    required this.onTap,
    required this.enabled,
    super.key,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<ComposePlayButton> createState() => _ComposePlayButtonState();
}

class ComposeTimeSigChip extends StatelessWidget {
  const ComposeTimeSigChip({
    required this.beatsPerMeasure,
    required this.beatUnit,
    super.key,
  });

  final int beatsPerMeasure;
  final int beatUnit;

  @override
  Widget build(BuildContext context) {
    return _CapsuleButton(
      onTap: () {
        showTimeSigPicker(context, context.read<ScoreNotifier>());
      },
      icon: Icons.music_note_rounded,
      label: '$beatsPerMeasure/$beatUnit',
    );
  }
}

class ComposeKeySigChip extends StatelessWidget {
  const ComposeKeySigChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _CapsuleButton(
      onTap: () {
        showKeySigPicker(context, context.read<ScoreNotifier>());
      },
      icon: Icons.queue_music_rounded,
      label: label,
    );
  }
}

class _ComposePlayButtonState extends State<ComposePlayButton>
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
      end: 0.94,
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
        if (widget.enabled) {
          widget.onTap();
        }
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
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
                        .withAlpha(widget.enabled ? 89 : 0),
                blurRadius: 14,
                offset: const Offset(0, 5),
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
    return _CapsuleButton(
      onTap: onTap,
      icon: icon,
      label: label,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      foregroundColor: AppColors.textPrimary,
      backgroundColor: AppColors.surfaceContainerHigh,
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.onTap,
    required this.icon,
    required this.label,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.foregroundColor = AppColors.textChip,
    this.backgroundColor = AppColors.surfaceContainerHigh,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final EdgeInsets padding;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final resolvedForeground = enabled
        ? foregroundColor
        : AppColors.textMuted.withAlpha(122);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: padding,
          decoration: BoxDecoration(
            color: enabled ? backgroundColor : backgroundColor.withAlpha(168),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? AppColors.surfaceBorder
                  : AppColors.surfaceBorder.withAlpha(128),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: resolvedForeground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: resolvedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
