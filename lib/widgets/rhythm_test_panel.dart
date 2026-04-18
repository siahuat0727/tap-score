import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/rhythm_test_notifier.dart';
import '../theme/app_colors.dart';
import 'input_affordance.dart';

typedef _RhythmTestPanelLayoutState = ({
  String? errorMessage,
  double bpm,
  double largeErrorThresholdBeats,
  bool isBusy,
});

typedef _RhythmTestActionState = ({
  bool primaryActionEnabled,
  String primaryActionLabel,
  String primaryActionHint,
  bool canStop,
});

class RhythmTestPanel extends StatelessWidget {
  const RhythmTestPanel({required this.onTempoChanged, super.key});

  final ValueChanged<double> onTempoChanged;

  @override
  Widget build(BuildContext context) {
    final state = context
        .select<RhythmTestNotifier, _RhythmTestPanelLayoutState>(
          (notifier) => (
            errorMessage: notifier.errorMessage,
            bpm: notifier.score.bpm,
            largeErrorThresholdBeats: notifier.largeErrorThresholdBeats,
            isBusy: notifier.isBusy,
          ),
        );

    return ColoredBox(
      color: AppColors.surfaceContainer,
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            state.errorMessage == null ? 12 : 14,
            16,
            state.errorMessage == null ? 14 : 16,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 420 || constraints.maxHeight < 190;
                final wide = constraints.maxWidth >= 700;
                final affordanceProfile = resolveInputAffordanceProfile(
                  context,
                  compact: !wide,
                );

                final parameters = _ParameterColumn(
                  bpm: state.bpm,
                  largeErrorThresholdBeats: state.largeErrorThresholdBeats,
                  enabled: !state.isBusy,
                  compact: compact,
                  onTempoChanged: onTempoChanged,
                );

                if (wide) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (state.errorMessage != null) ...[
                        _InfoBanner(message: state.errorMessage!),
                        const SizedBox(height: 14),
                      ],
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: parameters),
                            const SizedBox(width: 18),
                            Expanded(
                              child: _ActionGroup(
                                showKeyboardHint:
                                    affordanceProfile.showsKeyboardAffordances,
                                compact: false,
                                wide: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                if (compact) {
                  return Column(
                    children: [
                      if (state.errorMessage != null) ...[
                        _InfoBanner(message: state.errorMessage!),
                        const SizedBox(height: 8),
                      ],
                      Expanded(child: Center(child: parameters)),
                      const SizedBox(height: 8),
                      _ActionGroup(
                        showKeyboardHint:
                            affordanceProfile.showsKeyboardAffordances,
                        compact: true,
                        wide: false,
                      ),
                    ],
                  );
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.errorMessage != null) ...[
                      _InfoBanner(message: state.errorMessage!),
                      const SizedBox(height: 12),
                    ],
                    parameters,
                    const SizedBox(height: 16),
                    _ActionGroup(
                      showKeyboardHint:
                          affordanceProfile.showsKeyboardAffordances,
                      compact: false,
                      wide: false,
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x18C62828),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x55C62828)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.statusError,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ParameterColumn extends StatelessWidget {
  const _ParameterColumn({
    required this.bpm,
    required this.largeErrorThresholdBeats,
    required this.enabled,
    required this.compact,
    required this.onTempoChanged,
  });

  final double bpm;
  final double largeErrorThresholdBeats;
  final bool enabled;
  final bool compact;
  final ValueChanged<double> onTempoChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveCompact = compact || constraints.maxHeight < 170;
        final tempoStrip = _ParameterStrip(
          controlKeyPrefix: 'rhythm-test-tempo',
          key: const ValueKey('rhythm-test-tempo'),
          label: 'BPM',
          valueLabel: '${bpm.round()}',
          value: bpm,
          min: 40,
          max: 240,
          divisions: 200,
          compact: effectiveCompact,
          enabled: enabled,
          onChanged: onTempoChanged,
        );
        final thresholdStrip = _ParameterStrip(
          controlKeyPrefix: 'rhythm-test-threshold',
          key: const ValueKey('rhythm-test-threshold'),
          label: 'Large-offset threshold',
          valueLabel: '${largeErrorThresholdBeats.toStringAsFixed(2)} beat',
          value: largeErrorThresholdBeats,
          min: 0.05,
          max: 0.50,
          divisions: 45,
          compact: effectiveCompact,
          enabled: enabled,
          onChanged: context.read<RhythmTestNotifier>().setLargeErrorThreshold,
        );

        if (effectiveCompact) {
          return Row(
            children: [
              Expanded(child: tempoStrip),
              const SizedBox(width: 8),
              Expanded(child: thresholdStrip),
            ],
          );
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            tempoStrip,
            SizedBox(height: effectiveCompact ? 8 : 10),
            thresholdStrip,
          ],
        );
      },
    );
  }
}

class _ParameterStrip extends StatelessWidget {
  const _ParameterStrip({
    required super.key,
    required this.controlKeyPrefix,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.compact,
    required this.enabled,
    required this.onChanged,
  });

  final String controlKeyPrefix;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool compact;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = (max - min) / divisions;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 4 : 8,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ultraCompact = compact && constraints.maxWidth < 170;
            final labelBlock = SizedBox(
              width: ultraCompact ? 44 : (compact ? 98 : 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!ultraCompact)
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (!ultraCompact) const SizedBox(height: 2),
                  Text(
                    valueLabel,
                    key: ValueKey('$controlKeyPrefix-value'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: ultraCompact ? 11 : (compact ? 13 : 14),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
            final decrementButton = _AdjustButton(
              icon: Icons.remove_rounded,
              enabled: enabled,
              compact: compact,
              ultraCompact: ultraCompact,
              buttonKey: ValueKey('$controlKeyPrefix-decrement'),
              onPressed: () => onChanged((value - step).clamp(min, max)),
            );
            final incrementButton = _AdjustButton(
              icon: Icons.add_rounded,
              enabled: enabled,
              compact: compact,
              ultraCompact: ultraCompact,
              buttonKey: ValueKey('$controlKeyPrefix-increment'),
              onPressed: () => onChanged((value + step).clamp(min, max)),
            );
            final slider = Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: AppColors.panelSliderActive,
                  inactiveTrackColor: AppColors.panelSliderInactive,
                  thumbColor: AppColors.panelSliderActive,
                  overlayColor: AppColors.panelSliderActive.withAlpha(24),
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: ultraCompact ? 5 : 7,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: valueLabel,
                  onChanged: enabled ? onChanged : null,
                ),
              ),
            );

            return Row(
              children: [labelBlock, decrementButton, slider, incrementButton],
            );
          },
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    required this.icon,
    required this.enabled,
    required this.compact,
    required this.ultraCompact,
    required this.buttonKey,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final bool compact;
  final bool ultraCompact;
  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: ultraCompact ? 16 : (compact ? 18 : 20)),
      color: AppColors.textDark,
      disabledColor: AppColors.panelAdjustDisabled,
      splashRadius: ultraCompact ? 14 : (compact ? 18 : 20),
      constraints: BoxConstraints.tightFor(
        width: ultraCompact ? 22 : (compact ? 28 : 32),
        height: ultraCompact ? 22 : (compact ? 28 : 32),
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.enabled,
    required this.label,
    required this.hint,
    required this.showKeyboardHint,
    required this.compact,
    required this.wide,
  });

  final bool enabled;
  final String label;
  final String hint;
  final bool showKeyboardHint;
  final bool compact;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      key: const ValueKey('rhythm-test-primary'),
      onPressed: enabled
          ? () => context.read<RhythmTestNotifier>().performPrimaryAction()
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.panelActionBackground,
        disabledBackgroundColor: AppColors.panelActionDisabled,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 24 : 28,
          vertical: wide ? 20 : (compact ? 10 : 18),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            compact && showKeyboardHint ? '$label · $hint' : label,
            style: TextStyle(
              fontSize: wide ? 34 : (compact ? 18 : 24),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          if (!compact && showKeyboardHint) ...[
            SizedBox(height: wide ? 8 : 4),
            Text(
              hint,
              style: TextStyle(
                fontSize: wide ? 14 : 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xD9FFFFFF),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );

    if (wide) {
      return SizedBox.expand(child: button);
    }

    return SizedBox(
      width: double.infinity,
      height: compact ? 56 : 92,
      child: button,
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({
    required this.showKeyboardHint,
    required this.compact,
    required this.wide,
  });

  final bool showKeyboardHint;
  final bool compact;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final state = context.select<RhythmTestNotifier, _RhythmTestActionState>(
      (notifier) => (
        primaryActionEnabled: notifier.primaryActionEnabled,
        primaryActionLabel: notifier.primaryActionLabel,
        primaryActionHint: notifier.primaryActionHint,
        canStop: notifier.canStop,
      ),
    );

    if (wide) {
      return Stack(
        children: [
          Positioned.fill(
            child: _PrimaryActionButton(
              enabled: state.primaryActionEnabled,
              label: state.primaryActionLabel,
              hint: state.primaryActionHint,
              showKeyboardHint: showKeyboardHint,
              compact: compact,
              wide: wide,
            ),
          ),
          if (state.canStop)
            Positioned(
              top: 10,
              right: 10,
              child: _StopActionButton(compact: compact),
            ),
        ],
      );
    }

    if (!state.canStop) {
      return _PrimaryActionButton(
        enabled: state.primaryActionEnabled,
        label: state.primaryActionLabel,
        hint: state.primaryActionHint,
        showKeyboardHint: showKeyboardHint,
        compact: compact,
        wide: wide,
      );
    }

    return SizedBox(
      height: compact ? 56 : 92,
      child: Row(
        children: [
          Expanded(
            child: _PrimaryActionButton(
              enabled: state.primaryActionEnabled,
              label: state.primaryActionLabel,
              hint: state.primaryActionHint,
              showKeyboardHint: showKeyboardHint,
              compact: compact,
              wide: wide,
            ),
          ),
          const SizedBox(width: 10),
          _StopActionButton(compact: compact),
        ],
      ),
    );
  }
}

class _StopActionButton extends StatelessWidget {
  const _StopActionButton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('rhythm-test-stop'),
      onPressed: () => context.read<RhythmTestNotifier>().stop(),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(compact ? 86 : 108, compact ? 56 : 92),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 10 : 14,
        ),
        foregroundColor: AppColors.textDark,
        side: const BorderSide(color: AppColors.surfaceBorder),
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      icon: Icon(Icons.stop_rounded, size: compact ? 18 : 20),
      label: Text(
        'Stop',
        style: TextStyle(
          fontSize: compact ? 15 : 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
