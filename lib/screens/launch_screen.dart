import 'package:flutter/material.dart';

import '../models/portable_score_document.dart';
import '../services/preset_score_repository.dart';
import '../services/score_library_repository.dart';
import '../services/score_transfer_service.dart';
import '../theme/app_colors.dart';
import '../widgets/score_library_picker_dialog.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({
    required this.onStartBlank,
    required this.onStartPracticePreset,
    required this.onStartPracticeSaved,
    required this.onImportDocument,
    this.presetScoreRepository,
    this.scoreLibraryRepository,
    this.scoreTransferService,
    super.key,
  });

  final VoidCallback onStartBlank;
  final ValueChanged<String> onStartPracticePreset;
  final ValueChanged<String> onStartPracticeSaved;
  final ValueChanged<PortableScoreDocument> onImportDocument;
  final PresetScoreRepository? presetScoreRepository;
  final ScoreLibraryRepository? scoreLibraryRepository;
  final ScoreTransferService? scoreTransferService;

  Future<void> _showPracticePicker(BuildContext context) async {
    final selection = await showScoreLibraryPickerDialog(
      context: context,
      presetScoreRepository: presetScoreRepository,
      scoreLibraryRepository: scoreLibraryRepository,
    );
    if (selection == null) {
      return;
    }

    switch (selection.source) {
      case ScoreLibraryEntrySource.preset:
        onStartPracticePreset(selection.id);
      case ScoreLibraryEntrySource.saved:
        onStartPracticeSaved(selection.id);
    }
  }

  Future<void> _importScore(BuildContext context) async {
    final transferService = scoreTransferService ?? PlatformScoreTransferService();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final document = await transferService.importDocument();
      if (document == null) {
        return;
      }
      onImportDocument(document);
    } on ScoreTransferException catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Failed to import the selected score document.'),
          ),
        );
    }
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
          child: LayoutBuilder(
            builder: (context, viewport) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewport.maxHeight - 64,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 760;
                          final practiceHeight = constraints.maxHeight < 720
                              ? 276.0
                              : 332.0;

                          final practiceCard = _LaunchCard(
                            key: const ValueKey('launch-practice-card'),
                            title: 'Practice',
                            subtitle:
                                'Open a preset or saved score in rhythm test',
                            icon: Icons.library_music_outlined,
                            accentColor: AppColors.accentAmber,
                            onTap: () {
                              _showPracticePicker(context);
                            },
                          );
                          final blankCard = _LaunchCard(
                            key: const ValueKey('launch-new-blank-card'),
                            title: 'Create',
                            subtitle: 'Start from a blank score',
                            icon: Icons.add_box_outlined,
                            onTap: onStartBlank,
                          );
                          final importCard = _LaunchCard(
                            key: const ValueKey('launch-import-card'),
                            title: 'Import',
                            subtitle: 'Bring in a score file and edit it',
                            icon: Icons.upload_file_outlined,
                            onTap: () {
                              _importScore(context);
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
                                'Practice is the main path. Create or import when you need to edit.',
                                textAlign: TextAlign.center,
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
                                    SizedBox(
                                      height: practiceHeight,
                                      child: practiceCard,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 156,
                                            child: blankCard,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: SizedBox(
                                            height: 156,
                                            child: importCard,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                SizedBox(
                                  height: practiceHeight,
                                  child: Row(
                                    children: [
                                      Expanded(child: practiceCard),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Expanded(child: blankCard),
                                            const SizedBox(height: 18),
                                            Expanded(child: importCard),
                                          ],
                                        ),
                                      ),
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
              );
            },
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
    this.accentColor = AppColors.accentBlue,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 170;
            final padding = compact ? 18.0 : 28.0;
            final iconPadding = compact ? 10.0 : 14.0;
            final iconSize = compact ? 26.0 : 34.0;
            final titleSize = compact ? 24.0 : 30.0;
            final subtitleSize = compact ? 13.0 : 15.0;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: highlighted
                    ? AppColors.surfaceContainerHigh
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: highlighted
                      ? widget.accentColor.withAlpha(150)
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
                      color: widget.accentColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(iconPadding),
                      child: Icon(
                        widget.icon,
                        size: iconSize,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textBody,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
