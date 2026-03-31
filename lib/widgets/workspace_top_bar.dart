import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'playback_controls.dart';

class WorkspaceTopBarAction {
  const WorkspaceTopBarAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.buttonKey,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Key? buttonKey;
}

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    required this.title,
    required this.subtitle,
    this.leadingActions = const [],
    this.trailingAction,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<WorkspaceTopBarAction> leadingActions;
  final WorkspaceTopBarAction? trailingAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDim,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withAlpha(248),
          border: const Border(
            bottom: BorderSide(color: AppColors.surfaceDivider),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 900;
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in leadingActions)
                          _TopBarActionButton(action: action),
                        if (trailingAction case final action?)
                          _TopBarActionButton(
                            action: action,
                            foregroundColor: AppColors.accentBlue,
                            backgroundColor: AppColors.accentBlue.withAlpha(16),
                            borderColor: AppColors.accentBlue.withAlpha(80),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _WorkspaceTopBarTitle(
                      title: title,
                      subtitle: subtitle,
                      centered: false,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final action in leadingActions)
                          _TopBarActionButton(action: action),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _WorkspaceTopBarTitle(
                      title: title,
                      subtitle: subtitle,
                      centered: true,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailingAction == null
                          ? const SizedBox.shrink()
                          : _TopBarActionButton(
                              action: trailingAction!,
                              foregroundColor: AppColors.accentBlue,
                              backgroundColor: AppColors.accentBlue.withAlpha(
                                16,
                              ),
                              borderColor: AppColors.accentBlue.withAlpha(80),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTopBarTitle extends StatelessWidget {
  const _WorkspaceTopBarTitle({
    required this.title,
    required this.subtitle,
    required this.centered,
  });

  final String title;
  final String subtitle;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final textAlign = centered ? TextAlign.center : TextAlign.left;
    final crossAxisAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textBody,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: textAlign,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TopBarActionButton extends StatelessWidget {
  const _TopBarActionButton({
    required this.action,
    this.foregroundColor = AppColors.textChip,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.surfaceBorder,
  });

  final WorkspaceTopBarAction action;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return CapsuleActionButton(
      key: action.buttonKey,
      onTap: action.onTap,
      icon: action.icon,
      label: action.label,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
  }
}
