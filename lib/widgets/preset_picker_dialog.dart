import 'package:flutter/material.dart';

import '../models/score_library.dart';
import '../services/preset_score_repository.dart';
import '../theme/app_colors.dart';

Future<void> showPresetPickerDialog({
  required BuildContext context,
  required ValueChanged<String> onSelected,
  required String subtitle,
  PresetScoreRepository? presetScoreRepository,
}) async {
  final repository = presetScoreRepository ?? AssetPresetScoreRepository();
  final presetsFuture = repository.loadPresets();

  await showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
              future: presetsFuture,
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
                  subtitle: subtitle,
                  onSelected: (presetId) {
                    Navigator.of(context).pop();
                    onSelected(presetId);
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
    required this.subtitle,
    required this.onSelected,
  });

  final List<PresetScoreEntry> presets;
  final String subtitle;
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
        Text(
          subtitle,
          style: const TextStyle(
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
