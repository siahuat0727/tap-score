import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../input/editor_shortcuts.dart';
import '../models/enums.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';

/// A toolbar row showing note duration buttons and editing tools.
class DurationSelector extends StatelessWidget {
  const DurationSelector({
    required this.onRhythmTestTap,
    required this.rhythmTestEnabled,
    required this.rhythmTestActive,
    super.key,
  });

  final VoidCallback onRhythmTestTap;
  final bool rhythmTestEnabled;
  final bool rhythmTestActive;

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, child) {
        final durationGlyph = notifier.toolbarDuration.label;
        final buttons = [
          _SquareButton(
            buttonKey: const ValueKey('rest-tool'),
            tooltip: 'Rest',
            glyph: Text(
              notifier.toolbarDuration.restLabel,
              style: const TextStyle(fontSize: 22),
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
              glyph: Text(
                notifier.toolbarShowsRestDurations
                    ? duration.restLabel
                    : duration.label,
                style: const TextStyle(fontSize: 22),
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
            glyph: _CompoundGlyph(
              base: durationGlyph,
              overlay: const _GlyphDot(),
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
            tooltip: 'Slur',
            glyph: _CompoundGlyph(
              base: durationGlyph,
              overlay: const _GlyphArc(),
            ),
            shortcutLabel: slurShortcutLabel,
            isSelected: notifier.toolbarSlurSelected,
            onTap: notifier.slurButtonEnabled ? notifier.toggleSlurMode : null,
            activeColor: AppColors.toolSlur,
          ),
          _SquareButton(
            buttonKey: const ValueKey('triplet-tool'),
            tooltip: 'Triplet',
            glyph: _CompoundGlyph(
              base: durationGlyph,
              overlay: const _GlyphTriplet(),
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
          _RhythmTestButton(
            isEnabled: rhythmTestEnabled,
            isSelected: rhythmTestActive,
            onTap: onRhythmTestTap,
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 560) {
                return Wrap(spacing: 2, runSpacing: 8, children: buttons);
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: buttons),
              );
            },
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

class _RhythmTestButton extends StatelessWidget {
  const _RhythmTestButton({
    required this.isEnabled,
    required this.isSelected,
    required this.onTap,
  });

  final bool isEnabled;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.accentAmber
        : isEnabled
        ? AppColors.rhythmTestBorder
        : Colors.grey.withAlpha(38);

    return Tooltip(
      message: 'Rhythm Test',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          key: const ValueKey('rhythm-test-tool'),
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isEnabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 124,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isEnabled
                      ? [AppColors.rhythmTestGradientStart, AppColors.rhythmTestGradientEnd]
                      : [const Color(0xFFE0E0E0), const Color(0xFFBDBDBD)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: isEnabled
                    ? const [
                        BoxShadow(
                          color: Color(0x33F59E0B),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: isEnabled
                        ? AppColors.rhythmTestText
                        : const Color(0xFF757575),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rhythm Test',
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isEnabled
                            ? AppColors.rhythmTestText
                            : const Color(0xFF757575),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompoundGlyph extends StatelessWidget {
  const _CompoundGlyph({required this.base, required this.overlay});

  final String base;
  final Widget overlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(base, style: const TextStyle(fontSize: 20, height: 1)),
          ),
          Positioned.fill(child: overlay),
        ],
      ),
    );
  }
}

class _GlyphDot extends StatelessWidget {
  const _GlyphDot();

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.black;
    return Align(
      alignment: const Alignment(0.9, 0.12),
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _GlyphArc extends StatelessWidget {
  const _GlyphArc();

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.black;
    return Align(
      alignment: const Alignment(0.0, -0.85),
      child: Text('◠', style: TextStyle(fontSize: 12, color: color, height: 1)),
    );
  }
}

class _GlyphTriplet extends StatelessWidget {
  const _GlyphTriplet();

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.black;
    return Align(
      alignment: const Alignment(0.9, -0.85),
      child: Text(
        '3',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1,
        ),
      ),
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
