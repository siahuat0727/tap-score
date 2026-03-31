import 'package:flutter/material.dart';

import '../app/workspace_launch_config.dart';
import '../theme/app_colors.dart';
import 'playback_controls.dart';

class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    required this.scoreLabel,
    required this.mode,
    required this.rhythmTestEnabled,
    required this.hasUnsavedChanges,
    required this.onGoHome,
    required this.onSelectMode,
    required this.onLoad,
    required this.onSave,
    required this.onExport,
    super.key,
  });

  final String scoreLabel;
  final WorkspaceMode mode;
  final bool rhythmTestEnabled;
  final bool hasUnsavedChanges;
  final VoidCallback onGoHome;
  final ValueChanged<WorkspaceMode> onSelectMode;
  final VoidCallback onLoad;
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
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final homeButton = _CommandButton(
                buttonKey: const ValueKey('workspace-home-button'),
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: onGoHome,
              );
              final actionButtons = [
                _CommandButton(
                  buttonKey: const ValueKey('load-score-button'),
                  icon: Icons.folder_open_outlined,
                  label: 'Load',
                  onTap: onLoad,
                ),
                _CommandButton(
                  buttonKey: const ValueKey('save-score-button'),
                  icon: Icons.save_outlined,
                  label: 'Save',
                  onTap: onSave,
                  highlighted: hasUnsavedChanges,
                ),
                _CommandButton(
                  buttonKey: const ValueKey('export-score-button'),
                  icon: Icons.file_download_outlined,
                  label: 'Export',
                  onTap: () => onExport(context),
                ),
              ];
              final center = _WorkspaceTopBarCenter(
                scoreLabel: scoreLabel,
                modeSwitch: _WorkspaceModeSwitch(
                  mode: mode,
                  rhythmTestEnabled:
                      rhythmTestEnabled || mode == WorkspaceMode.rhythmTest,
                  onSelectMode: onSelectMode,
                ),
              );

              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    Row(
                      children: [
                        homeButton,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: actionButtons,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    center,
                  ],
                );
              }

              return Row(
                children: [
                  homeButton,
                  const SizedBox(width: 16),
                  Expanded(child: center),
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: actionButtons,
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

class _WorkspaceTopBarCenter extends StatelessWidget {
  const _WorkspaceTopBarCenter({
    required this.scoreLabel,
    required this.modeSwitch,
  });

  final String scoreLabel;
  final Widget modeSwitch;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          scoreLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        modeSwitch,
      ],
    );
  }
}

class _WorkspaceModeSwitch extends StatelessWidget {
  const _WorkspaceModeSwitch({
    required this.mode,
    required this.rhythmTestEnabled,
    required this.onSelectMode,
  });

  final WorkspaceMode mode;
  final bool rhythmTestEnabled;
  final ValueChanged<WorkspaceMode> onSelectMode;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  key: const ValueKey('workspace-mode-compose'),
                  icon: Icons.edit_outlined,
                  label: 'Compose',
                  selected: mode == WorkspaceMode.compose,
                  onTap: () => onSelectMode(WorkspaceMode.compose),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ModeButton(
                  key: const ValueKey('workspace-mode-rhythm-test'),
                  icon: Icons.timer_outlined,
                  label: 'Rhythm Test',
                  selected: mode == WorkspaceMode.rhythmTest,
                  enabled: rhythmTestEnabled,
                  onTap: () => onSelectMode(WorkspaceMode.rhythmTest),
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
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected
        ? AppColors.surface
        : enabled
        ? AppColors.textBody
        : AppColors.textMuted.withAlpha(122);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentBlue
                : enabled
                ? Colors.transparent
                : AppColors.surfaceContainer.withAlpha(160),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.accentBlue
                  : enabled
                  ? AppColors.surfaceBorder
                  : AppColors.surfaceBorder.withAlpha(140),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foregroundColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
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

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final Key? buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return CapsuleActionButton(
      key: buttonKey,
      onTap: onTap,
      icon: icon,
      label: label,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      foregroundColor: highlighted
          ? AppColors.accentAmber
          : AppColors.textPrimary,
      backgroundColor: highlighted
          ? AppColors.accentAmber.withAlpha(24)
          : AppColors.surfaceContainerHigh,
      borderColor: highlighted
          ? AppColors.accentAmber.withAlpha(140)
          : AppColors.surfaceBorder,
    );
  }
}
