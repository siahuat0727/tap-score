import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../input/editor_shortcuts.dart';
import '../models/enums.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import 'playback_controls.dart';

const Map<NoteDuration, String> _noteGlyphAssets = {
  NoteDuration.whole: 'assets/icons/toolbar/note_whole.svg',
  NoteDuration.half: 'assets/icons/toolbar/note_half_up.svg',
  NoteDuration.quarter: 'assets/icons/toolbar/note_quarter_up.svg',
  NoteDuration.eighth: 'assets/icons/toolbar/note_8th_up.svg',
  NoteDuration.sixteenth: 'assets/icons/toolbar/note_16th_up.svg',
  NoteDuration.thirtySecond: 'assets/icons/toolbar/note_32nd_up.svg',
};

const Map<NoteDuration, String> _restGlyphAssets = {
  NoteDuration.whole: 'assets/icons/toolbar/rest_whole.svg',
  NoteDuration.half: 'assets/icons/toolbar/rest_half.svg',
  NoteDuration.quarter: 'assets/icons/toolbar/rest_quarter.svg',
  NoteDuration.eighth: 'assets/icons/toolbar/rest_8th.svg',
  NoteDuration.sixteenth: 'assets/icons/toolbar/rest_16th.svg',
  NoteDuration.thirtySecond: 'assets/icons/toolbar/rest_32nd.svg',
};

const String _noteQuarterWithDotAsset =
    'assets/icons/toolbar/note_quarter_up_with_dot.svg';
const String _noteQuarterWithTieAsset =
    'assets/icons/toolbar/note_quarter_up_with_tie.svg';
const String _tupletBracketWithThreeAsset =
    'assets/icons/toolbar/tuplet_bracket_with_3.svg';
const double _modifierGlyphWidth = 28;
const double _modifierGlyphHeight = 30;

/// A toolbar row showing note duration buttons and editing tools.
class DurationSelector extends StatelessWidget {
  const DurationSelector({
    this.leadingControls = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    super.key,
  });

  final List<Widget> leadingControls;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, child) {
        final buttons = [
          ...leadingControls,
          _SquareButton(
            buttonKey: const ValueKey('rest-tool'),
            tooltip: 'Rest',
            glyph: _DurationGlyph(
              duration: notifier.toolbarDuration,
              isRest: true,
            ),
            shortcutLabel: restShortcutLabel,
            isSelected: notifier.toolbarRestSelected,
            onTap: notifier.timingControlsEnabled
                ? notifier.handleRestAction
                : null,
            activeColor: AppColors.toolRest,
          ),
          ...NoteDuration.values.map(
            (duration) => _SquareButton(
              buttonKey: ValueKey('duration-${duration.name}'),
              tooltip: duration.name,
              glyph: _DurationGlyph(
                duration: duration,
                isRest: notifier.toolbarShowsRestDurations,
              ),
              shortcutLabel: durationShortcutLabels[duration]!,
              isSelected: notifier.toolbarDuration == duration,
              onTap: notifier.durationButtonsEnabled
                  ? () => notifier.setDuration(duration)
                  : null,
              activeColor: AppColors.toolDuration,
            ),
          ),
          _SquareButton(
            buttonKey: const ValueKey('dot-tool'),
            tooltip: 'Dot',
            glyph: const _ModifierAssetGlyph(
              _noteQuarterWithDotAsset,
              boxKey: ValueKey('dot-tool-glyph-box'),
            ),
            shortcutLabel: dottedShortcutLabel,
            isSelected: notifier.toolbarDottedSelected,
            onTap: notifier.timingControlsEnabled
                ? notifier.toggleDottedMode
                : null,
            activeColor: AppColors.toolDot,
          ),
          _SquareButton(
            buttonKey: const ValueKey('slur-tool'),
            tooltip: 'Tie / Slur',
            glyph: const _ModifierAssetGlyph(
              _noteQuarterWithTieAsset,
              boxKey: ValueKey('slur-tool-glyph-box'),
            ),
            shortcutLabel: slurShortcutLabel,
            isSelected: notifier.toolbarSlurSelected,
            onTap: notifier.slurButtonEnabled ? notifier.toggleSlurMode : null,
            activeColor: AppColors.toolSlur,
          ),
          _SquareButton(
            buttonKey: const ValueKey('triplet-tool'),
            tooltip: 'Triplet',
            glyph: const _ModifierAssetGlyph(
              _tupletBracketWithThreeAsset,
              boxKey: ValueKey('triplet-tool-glyph-box'),
            ),
            shortcutLabel: tripletShortcutLabel,
            isSelected: notifier.toolbarTripletSelected,
            onTap: notifier.tripletButtonEnabled
                ? notifier.toggleTripletMode
                : null,
            activeColor: AppColors.toolTriplet,
          ),
          _SquareButton(
            buttonKey: const ValueKey('delete-tool'),
            tooltip: 'Delete',
            glyph: const Icon(Icons.delete_outline, size: 20),
            isSelected: false,
            onTap: notifier.deleteButtonEnabled
                ? notifier.deleteSelected
                : null,
            activeColor: AppColors.toolDelete,
          ),
        ];

        return Padding(
          padding: padding,
          child: Wrap(
            spacing: 2,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: buttons,
          ),
        );
      },
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.glyph,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    this.buttonKey,
    this.tooltip,
    this.shortcutLabel,
  });

  final Key? buttonKey;
  final String? tooltip;
  final Widget glyph;
  final String? shortcutLabel;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = isSelected
        ? activeColor
        : enabled
        ? Colors.grey.shade700
        : Colors.grey.shade300;

    Widget button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        key: buttonKey,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withAlpha(38)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? activeColor
                    : enabled
                    ? Colors.grey.withAlpha(77)
                    : Colors.grey.withAlpha(38),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IconTheme(
                    data: IconThemeData(color: foreground),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Center(child: glyph),
                    ),
                  ),
                ),
                if (shortcutLabel != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _ShortcutBadge(label: shortcutLabel!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}

class _DurationGlyph extends StatelessWidget {
  const _DurationGlyph({required this.duration, this.isRest = false});

  final NoteDuration duration;
  final bool isRest;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.black;
    final assetPath = (isRest ? _restGlyphAssets : _noteGlyphAssets)[duration]!;

    return SizedBox(
      width: 26,
      height: 26,
      child: SvgPicture.asset(
        assetPath,
        width: 26,
        height: 26,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

class _ToolbarAssetGlyph extends StatelessWidget {
  const _ToolbarAssetGlyph(
    this.assetPath, {
    this.boxKey,
    this.width = 26,
    this.height = 26,
    this.alignment = Alignment.center,
  });

  final String assetPath;
  final Key? boxKey;
  final double width;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.black;
    return Align(
      alignment: alignment,
      child: SizedBox(
        key: boxKey,
        width: width,
        height: height,
        child: SvgPicture.asset(
          assetPath,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _ModifierAssetGlyph extends StatelessWidget {
  const _ModifierAssetGlyph(this.assetPath, {this.boxKey});

  final String assetPath;
  final Key? boxKey;

  @override
  Widget build(BuildContext context) {
    return _ToolbarAssetGlyph(
      assetPath,
      boxKey: boxKey,
      width: _modifierGlyphWidth,
      height: _modifierGlyphHeight,
      alignment: Alignment.bottomCenter,
    );
  }
}

class ToolbarEditStrip extends StatelessWidget {
  const ToolbarEditStrip({this.padding = EdgeInsets.zero, super.key});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DurationSelector(padding: padding);
  }
}

class ToolbarInfoChips extends StatelessWidget {
  const ToolbarInfoChips({
    required this.beatsPerMeasure,
    required this.beatUnit,
    required this.keyLabel,
    required this.bpm,
    required this.tempoEnabled,
    super.key,
  });

  final int beatsPerMeasure;
  final int beatUnit;
  final String keyLabel;
  final double bpm;
  final bool tempoEnabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        ComposeTimeSigChip(
          key: const ValueKey('compose-time-signature'),
          beatsPerMeasure: beatsPerMeasure,
          beatUnit: beatUnit,
        ),
        ComposeKeySigChip(
          key: const ValueKey('compose-key-signature'),
          label: keyLabel,
        ),
        ComposeTempoChip(
          key: const ValueKey('compose-tempo'),
          bpm: bpm,
          enabled: tempoEnabled,
        ),
      ],
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.shortcutBadgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
