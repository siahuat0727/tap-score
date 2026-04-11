import 'package:flutter/material.dart';

import '../app/workspace_launch_config.dart';
import '../theme/app_colors.dart';

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    required this.mode,
    required this.showsEditorActions,
    required this.isInteractive,
    required this.hasUnsavedChanges,
    required this.onGoHome,
    required this.onSelectMode,
    required this.onSave,
    required this.onExport,
    super.key,
  });

  final WorkspaceMode mode;
  final bool showsEditorActions;
  final bool isInteractive;
  final bool hasUnsavedChanges;
  final VoidCallback onGoHome;
  final ValueChanged<WorkspaceMode> onSelectMode;
  final VoidCallback onSave;
  final ValueChanged<BuildContext> onExport;

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
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1040;
              final ultraCompact = constraints.maxWidth < 420;
              final trailingWidth = compact ? 88.0 : 252.0;
              final homeButton = SizedBox(
                width: 40,
                child: _ToolbarIconButton(
                  buttonKey: const ValueKey('workspace-home-button'),
                  icon: Icons.home_outlined,
                  tooltip: 'Home',
                  onTap: onGoHome,
                ),
              );
              final modeSwitch = _WorkspaceModeSwitch(
                mode: mode,
                compact: compact,
                ultraCompact: ultraCompact,
                isInteractive: isInteractive,
                onSelectMode: onSelectMode,
              );
              final trailingActions = Align(
                alignment: Alignment.centerRight,
                child: showsEditorActions
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToolbarActionButton(
                            buttonKey: const ValueKey('save-score-button'),
                            icon: Icons.save_outlined,
                            label: 'Save',
                            compact: compact,
                            highlighted: hasUnsavedChanges,
                            onTap: isInteractive ? onSave : null,
                          ),
                          const SizedBox(width: 8),
                          _ToolbarActionButton(
                            buttonKey: const ValueKey('export-score-button'),
                            icon: Icons.file_download_outlined,
                            label: 'Export',
                            compact: compact,
                            onTap: isInteractive
                                ? () => onExport(context)
                                : null,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              );

              if (ultraCompact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [homeButton, const Spacer(), trailingActions],
                    ),
                    const SizedBox(height: 10),
                    modeSwitch,
                  ],
                );
              }

              return Row(
                children: [
                  homeButton,
                  const SizedBox(width: 10),
                  Expanded(child: Center(child: modeSwitch)),
                  const SizedBox(width: 10),
                  SizedBox(width: trailingWidth, child: trailingActions),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkspaceModeSwitch extends StatelessWidget {
  const _WorkspaceModeSwitch({
    required this.mode,
    required this.compact,
    required this.ultraCompact,
    required this.isInteractive,
    required this.onSelectMode,
  });

  final WorkspaceMode mode;
  final bool compact;
  final bool ultraCompact;
  final bool isInteractive;
  final ValueChanged<WorkspaceMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: ultraCompact ? 224 : (compact ? 280 : 340),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  key: const ValueKey('workspace-mode-compose'),
                  icon: Icons.edit_outlined,
                  label: ultraCompact ? 'Edit' : 'Editor',
                  selected: mode == WorkspaceMode.compose,
                  compact: ultraCompact,
                  onTap: isInteractive
                      ? () => onSelectMode(WorkspaceMode.compose)
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _ModeButton(
                  key: const ValueKey('workspace-mode-rhythm-test'),
                  icon: Icons.timer_outlined,
                  label: ultraCompact ? 'Test' : 'Rhythm Test',
                  selected: mode == WorkspaceMode.rhythmTest,
                  compact: ultraCompact,
                  onTap: isInteractive
                      ? () => onSelectMode(WorkspaceMode.rhythmTest)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    this.compact = false,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final foregroundColor = selected
        ? AppColors.surface
        : isEnabled
        ? AppColors.textBody
        : AppColors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: compact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.accentBlue
                  : isEnabled
                  ? AppColors.surfaceBorder
                  : AppColors.surfaceDivider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 15 : 16, color: foregroundColor),
              SizedBox(width: compact ? 4 : 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Icon(icon, size: 18, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  const _ToolbarActionButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
    this.highlighted = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final foregroundColor = highlighted
        ? AppColors.accentAmber
        : isEnabled
        ? AppColors.textPrimary
        : AppColors.textMuted;
    final backgroundColor = highlighted
        ? AppColors.accentAmber.withAlpha(24)
        : isEnabled
        ? AppColors.surfaceContainerHigh
        : AppColors.surface;
    final borderColor = highlighted
        ? AppColors.accentAmber.withAlpha(140)
        : isEnabled
        ? AppColors.surfaceBorder
        : AppColors.surfaceDivider;

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: compact ? 40 : null,
            height: 40,
            padding: compact
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: compact
                ? Icon(icon, size: 18, color: foregroundColor)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: foregroundColor),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: foregroundColor,
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
