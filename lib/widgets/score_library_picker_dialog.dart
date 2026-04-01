import 'package:flutter/material.dart';

import '../models/score_library.dart';
import '../services/preset_score_repository.dart';
import '../services/score_library_repository.dart';
import '../theme/app_colors.dart';

enum ScoreLibraryEntrySource { preset, saved }

class ScoreLibrarySelection {
  const ScoreLibrarySelection({required this.source, required this.id});

  final ScoreLibraryEntrySource source;
  final String id;
}

Future<ScoreLibrarySelection?> showScoreLibraryPickerDialog({
  required BuildContext context,
  PresetScoreRepository? presetScoreRepository,
  ScoreLibraryRepository? scoreLibraryRepository,
}) async {
  final presetRepository = presetScoreRepository ?? AssetPresetScoreRepository();
  final libraryRepository =
      scoreLibraryRepository ?? SharedPreferencesScoreLibraryRepository();

  final presetsFuture = presetRepository.loadPresets();
  final snapshotFuture = libraryRepository.loadSnapshot();

  return showDialog<ScoreLibrarySelection>(
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
            child: FutureBuilder<_PickerData>(
              future: _loadPickerData(
                presetsFuture: presetsFuture,
                snapshotFuture: snapshotFuture,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _PickerLoading();
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = switch (error) {
                    PresetScoreException(:final message) => message,
                    ScoreLibraryStorageException(:final message) => message,
                    _ => 'Failed to load practice scores.',
                  };
                  return _PickerMessage(
                    key: const ValueKey('launch-practice-modal-error'),
                    title: 'Practice',
                    message: message,
                    isError: true,
                  );
                }

                final data = snapshot.data;
                if (data == null || data.entries.isEmpty) {
                  return const _PickerMessage(
                    key: ValueKey('launch-practice-modal-empty'),
                    title: 'Practice',
                    message: 'No presets or saved scores available.',
                  );
                }

                return _PickerList(entries: data.entries);
              },
            ),
          ),
        ),
      );
    },
  );
}

Future<_PickerData> _loadPickerData({
  required Future<List<PresetScoreEntry>> presetsFuture,
  required Future<ScoreLibrarySnapshot?> snapshotFuture,
}) async {
  final presets = await presetsFuture;
  final snapshot = await snapshotFuture;
  return _PickerData(
    entries: [
      for (final entry in presets) _PickerEntry.preset(entry),
      for (final entry in snapshot?.savedScores ?? const <SavedScoreEntry>[])
        _PickerEntry.saved(entry),
    ],
  );
}

class _PickerData {
  const _PickerData({required this.entries});

  final List<_PickerEntry> entries;
}

class _PickerEntry {
  const _PickerEntry.preset(this.preset)
    : saved = null,
      source = ScoreLibraryEntrySource.preset;

  const _PickerEntry.saved(this.saved)
    : preset = null,
      source = ScoreLibraryEntrySource.saved;

  final ScoreLibraryEntrySource source;
  final PresetScoreEntry? preset;
  final SavedScoreEntry? saved;

  String get id => preset?.id ?? saved!.id;
  String get title => preset?.name ?? saved!.name;
  String get subtitle => switch (source) {
    ScoreLibraryEntrySource.preset => 'Preset',
    ScoreLibraryEntrySource.saved => 'Saved score',
  };
}

class _PickerLoading extends StatelessWidget {
  const _PickerLoading();

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

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({
    required this.title,
    required this.message,
    this.isError = false,
    super.key,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(
            color: isError ? AppColors.statusError : AppColors.textMuted,
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

class _PickerList extends StatelessWidget {
  const _PickerList({required this.entries});

  final List<_PickerEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('launch-practice-modal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Practice',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a preset or saved score to open in rhythm test.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _PickerTile(
                entry: entry,
                onTap: () {
                  Navigator.of(context).pop(
                    ScoreLibrarySelection(source: entry.source, id: entry.id),
                  );
                },
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

class _PickerTile extends StatefulWidget {
  const _PickerTile({required this.entry, required this.onTap});

  final _PickerEntry entry;
  final VoidCallback onTap;

  @override
  State<_PickerTile> createState() => _PickerTileState();
}

class _PickerTileState extends State<_PickerTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isPreset = widget.entry.source == ScoreLibraryEntrySource.preset;
    final accentColor = isPreset ? AppColors.accentBlue : AppColors.accentAmber;
    final icon = isPreset ? Icons.library_music_outlined : Icons.save_outlined;
    final keyPrefix = isPreset ? 'practice-preset' : 'practice-saved';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('$keyPrefix-${widget.entry.id}'),
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
                    ? accentColor.withAlpha(120)
                    : AppColors.surfaceBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.entry.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
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
