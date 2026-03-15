import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../state/score_notifier.dart';

/// A toolbar row showing note duration buttons and a rest toggle.
class DurationSelector extends StatelessWidget {
  const DurationSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Duration buttons
              ...NoteDuration.values.map(
                (duration) => _DurationButton(
                  duration: duration,
                  isSelected: notifier.currentDuration == duration,
                  onTap: () => notifier.setDuration(duration),
                ),
              ),
              const SizedBox(width: 12),
              // Rest toggle
              _ToolButton(
                icon: Icons.hotel,
                label: 'Rest',
                isSelected: notifier.restMode,
                onTap: notifier.toggleRestMode,
                activeColor: const Color(0xFF9C27B0),
              ),
              const SizedBox(width: 8),
              // Delete button
              _ToolButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                isSelected: false,
                onTap: notifier.selectedIndex != null ? notifier.deleteSelected : null,
                activeColor: const Color(0xFFF44336),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DurationButton extends StatelessWidget {
  final NoteDuration duration;
  final bool isSelected;
  final VoidCallback onTap;

  const _DurationButton({
    required this.duration,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
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
                    : Colors.grey.withAlpha(77),
                width: isSelected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              duration.label,
              style: TextStyle(
                fontSize: 22,
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color activeColor;

  const _ToolButton({
    required this.icon,
    required this.label,
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
