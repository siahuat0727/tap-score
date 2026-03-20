import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../input/editor_shortcuts.dart';
import '../models/enums.dart';
import '../state/score_notifier.dart';

/// A toolbar row showing note duration buttons and editing tools.
class DurationSelector extends StatelessWidget {
  const DurationSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ToolButton(
                  buttonKey: const ValueKey('rest-tool'),
                  icon: Icons.hotel,
                  label: 'Rest',
                  shortcutLabel: restShortcutLabel,
                  isSelected: notifier.toolbarRestSelected,
                  onTap: notifier.timingControlsEnabled
                      ? notifier.handleRestAction
                      : null,
                  activeColor: const Color(0xFF9C27B0),
                ),
                const SizedBox(width: 8),
                ...NoteDuration.values.map(
                  (duration) => _DurationButton(
                    buttonKey: ValueKey('duration-${duration.name}'),
                    displayLabel: notifier.toolbarShowsRestDurations
                        ? duration.restLabel
                        : duration.label,
                    shortcutLabel: durationShortcutLabels[duration]!,
                    isSelected: notifier.toolbarDuration == duration,
                    onTap: notifier.timingControlsEnabled
                        ? () => notifier.setDuration(duration)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                _ToolButton(
                  buttonKey: const ValueKey('dot-tool'),
                  icon: Icons.fiber_manual_record,
                  label: 'Dot',
                  shortcutLabel: dottedShortcutLabel,
                  isSelected: notifier.toolbarDottedSelected,
                  onTap: notifier.timingControlsEnabled
                      ? notifier.toggleDottedMode
                      : null,
                  activeColor: const Color(0xFFFF9800),
                ),
                const SizedBox(width: 4),
                _ToolButton(
                  buttonKey: const ValueKey('triplet-tool'),
                  icon: Icons.looks_3,
                  label: 'Trip',
                  shortcutLabel: tripletShortcutLabel,
                  isSelected: notifier.toolbarTripletSelected,
                  onTap: notifier.tripletButtonEnabled
                      ? notifier.toggleTripletMode
                      : null,
                  activeColor: const Color(0xFF00897B),
                ),
                const SizedBox(width: 8),
                _ToolButton(
                  buttonKey: const ValueKey('delete-tool'),
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  isSelected: false,
                  onTap: notifier.selectedIndex != null
                      ? notifier.deleteSelected
                      : null,
                  activeColor: const Color(0xFFF44336),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DurationButton extends StatelessWidget {
  final Key? buttonKey;
  final String displayLabel;
  final String shortcutLabel;
  final bool isSelected;
  final VoidCallback? onTap;

  const _DurationButton({
    this.buttonKey,
    required this.displayLabel,
    required this.shortcutLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Padding(
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
                  ? const Color(0xFF2196F3).withAlpha(38)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2196F3)
                    : enabled
                    ? Colors.grey.withAlpha(77)
                    : Colors.grey.withAlpha(38),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      fontSize: 22,
                      color: isSelected
                          ? const Color(0xFF2196F3)
                          : enabled
                          ? Colors.grey[600]
                          : Colors.grey[300],
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _ShortcutBadge(label: shortcutLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final Key? buttonKey;
  final IconData icon;
  final String label;
  final String? shortcutLabel;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color activeColor;

  const _ToolButton({
    this.buttonKey,
    required this.icon,
    required this.label,
    this.shortcutLabel,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        key: buttonKey,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? activeColor
                      : enabled
                      ? Colors.grey[600]
                      : Colors.grey[300],
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? activeColor
                        : enabled
                        ? Colors.grey[600]
                        : Colors.grey[300],
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                if (shortcutLabel != null) ...[
                  const SizedBox(width: 8),
                  _ShortcutBadge(label: shortcutLabel!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  final String label;

  const _ShortcutBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF2F4156),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          height: 1,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
