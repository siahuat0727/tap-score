import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../painters/staff_painter.dart';
import '../state/score_notifier.dart';

/// Widget that displays the musical staff and handles tap interaction.
class StaffView extends StatefulWidget {
  const StaffView({super.key});

  @override
  State<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<StaffView> {
  final ScrollController _scrollController = ScrollController();
  StaffPainter? _lastPainter;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, child) {
        final painter = StaffPainter(
          score: notifier.score,
          selectedIndex: notifier.selectedIndex,
          cursorIndex: notifier.cursorIndex,
          playbackIndex: notifier.playbackIndex,
        );
        _lastPainter = painter;

        final totalWidth = painter.totalWidth.clamp(
          MediaQuery.of(context).size.width,
          double.infinity,
        );

        // Auto-scroll to cursor during playback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoScrollToCursor(notifier, totalWidth);
        });

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0), // Warm parchment background
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                onTapUp: (details) => _handleTap(details, notifier),
                child: CustomPaint(
                  painter: painter,
                  size: Size(totalWidth, 200),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _autoScrollToCursor(ScoreNotifier notifier, double totalWidth) {
    if (!_scrollController.hasClients) return;
    
    final cursorBeatOffset = notifier.score.beatOffsetAt(
      notifier.isPlaying ? notifier.playbackIndex.clamp(0, notifier.score.notes.length) : notifier.cursorIndex,
    );
    final cursorX = StaffPainter.leftMargin + cursorBeatOffset * StaffPainter.noteSpacing;
    
    final viewportWidth = _scrollController.position.viewportDimension;
    final currentScroll = _scrollController.offset;
    
    // Scroll if cursor is outside the visible area
    if (cursorX < currentScroll + 50 || cursorX > currentScroll + viewportWidth - 50) {
      _scrollController.animateTo(
        (cursorX - viewportWidth / 2).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleTap(TapUpDetails details, ScoreNotifier notifier) {
    if (notifier.isPlaying) return;

    final tapPosition = details.localPosition;

    // Check if tap is on an existing note
    if (_lastPainter != null) {
      for (final layout in _lastPainter!.noteLayouts) {
        if (layout.rect.contains(tapPosition)) {
          notifier.selectNote(layout.index);
          return;
        }
      }
    }

    // Tap on staff: calculate the pitch from Y position
    final staffTop = StaffPainter.staffTopMargin;
    final staffBottom = staffTop + 4 * StaffPainter.lineSpacing;
    
    // Only handle taps near the staff area (with some padding)
    final expandedTop = staffTop - StaffPainter.lineSpacing * 4;
    final expandedBottom = staffBottom + StaffPainter.lineSpacing * 4;
    
    if (tapPosition.dy >= expandedTop && tapPosition.dy <= expandedBottom) {
      // Convert Y to staff position
      final staffPos = ((staffBottom - tapPosition.dy) / (StaffPainter.lineSpacing / 2)).round();
      final midi = Note.staffPositionToMidi(staffPos);
      
      // Only accept reasonable MIDI range
      if (midi >= 48 && midi <= 84) { // C3 to C6
        notifier.insertNote(midi);
      }
    }
  }
}
