import 'package:flutter/material.dart';

import '../services/preset_score_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/preset_picker_dialog.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({
    required this.onStartBlank,
    required this.onStartPracticePreset,
    this.presetScoreRepository,
    super.key,
  });

  final VoidCallback onStartBlank;
  final ValueChanged<String> onStartPracticePreset;
  final PresetScoreRepository? presetScoreRepository;

  Future<void> _showPresetPicker(BuildContext context) {
    return showPresetPickerDialog(
      context: context,
      presetScoreRepository: presetScoreRepository,
      subtitle: 'Choose a preset to start the rhythm test',
      onSelected: onStartPracticePreset,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFCF7), Color(0xFFF2EEE5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 700;
                    final cardHeight = constraints.maxHeight < 640
                        ? 180.0
                        : 240.0;
                    final blankCard = _LaunchCard(
                      key: const ValueKey('launch-new-blank-card'),
                      title: 'Create New Score',
                      subtitle: 'Start composing from a blank score',
                      icon: Icons.add_box_outlined,
                      onTap: onStartBlank,
                    );
                    final presetCard = _LaunchCard(
                      key: const ValueKey('launch-preset-card'),
                      title: 'Practice from Preset',
                      subtitle: 'Choose a preset and start the rhythm test',
                      icon: Icons.library_music_outlined,
                      onTap: () {
                        _showPresetPicker(context);
                      },
                    );

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Tap Score',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Choose whether you want to compose or practice.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (stacked)
                          Column(
                            children: [
                              SizedBox(height: cardHeight, child: blankCard),
                              const SizedBox(height: 16),
                              SizedBox(height: cardHeight, child: presetCard),
                            ],
                          )
                        else
                          SizedBox(
                            height: 320,
                            child: Row(
                              children: [
                                Expanded(child: blankCard),
                                const SizedBox(width: 20),
                                Expanded(child: presetCard),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchCard extends StatefulWidget {
  const _LaunchCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_LaunchCard> createState() => _LaunchCardState();
}

class _LaunchCardState extends State<_LaunchCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _isHovered || _isPressed;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.surfaceContainerHigh
                : AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: highlighted
                  ? AppColors.accentAmber.withAlpha(150)
                  : AppColors.surfaceBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(highlighted ? 22 : 10),
                blurRadius: highlighted ? 26 : 14,
                offset: Offset(0, highlighted ? 14 : 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withAlpha(22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    widget.icon,
                    size: 34,
                    color: AppColors.accentAmber,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBody,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
