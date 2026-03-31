import 'package:flutter/material.dart';

import '../models/score_library.dart';
import '../services/preset_score_repository.dart';
import '../theme/app_colors.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({
    required this.onStartBlank,
    required this.onStartPreset,
    this.presetScoreRepository,
    super.key,
  });

  final VoidCallback onStartBlank;
  final ValueChanged<String> onStartPreset;
  final PresetScoreRepository? presetScoreRepository;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  late final PresetScoreRepository _presetScoreRepository =
      widget.presetScoreRepository ?? AssetPresetScoreRepository();
  late final Future<List<PresetScoreEntry>> _presetsFuture =
      _presetScoreRepository.loadPresets();

  Future<void> _showPresetPicker() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: AppColors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: FutureBuilder<List<PresetScoreEntry>>(
                future: _presetsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _PresetPickerLoading();
                  }

                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    final message = error is PresetScoreException
                        ? error.message
                        : 'Failed to load presets.';
                    return _PresetPickerError(message: message);
                  }

                  final presets = snapshot.data;
                  if (presets == null || presets.isEmpty) {
                    return const _PresetPickerEmpty();
                  }

                  return _PresetPickerList(
                    presets: presets,
                    onSelected: (presetId) {
                      Navigator.of(context).pop();
                      widget.onStartPreset(presetId);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
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
                      title: 'New Blank Score',
                      subtitle: 'Start from an empty draft',
                      icon: Icons.add_box_outlined,
                      onTap: widget.onStartBlank,
                    );
                    final presetCard = _LaunchCard(
                      key: const ValueKey('launch-preset-card'),
                      title: 'Start from Preset',
                      subtitle: 'Choose a template and begin editing',
                      icon: Icons.library_music_outlined,
                      onTap: _showPresetPicker,
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
                          'Pick how you want to start.',
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

class _PresetPickerLoading extends StatelessWidget {
  const _PresetPickerLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _PresetPickerError extends StatelessWidget {
  const _PresetPickerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('launch-preset-modal-error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Presets',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(
            color: AppColors.statusError,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}

class _PresetPickerEmpty extends StatelessWidget {
  const _PresetPickerEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('launch-preset-modal-empty'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Presets',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        const Text(
          'No presets available.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}

class _PresetPickerList extends StatelessWidget {
  const _PresetPickerList({
    required this.presets,
    required this.onSelected,
  });

  final List<PresetScoreEntry> presets;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('launch-preset-modal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Presets',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a starting point for your draft.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: presets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final preset = presets[index];
              return _PresetListTile(
                preset: preset,
                onTap: () => onSelected(preset.id),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

class _PresetListTile extends StatefulWidget {
  const _PresetListTile({required this.preset, required this.onTap});

  final PresetScoreEntry preset;
  final VoidCallback onTap;

  @override
  State<_PresetListTile> createState() => _PresetListTileState();
}

class _PresetListTileState extends State<_PresetListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('preset-option-${widget.preset.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppColors.surface.withAlpha(230)
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? AppColors.accentBlue.withAlpha(120)
                    : AppColors.surfaceBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.preset.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
