import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/score.dart';
import '../models/enums.dart';

/// Layout information for a rendered note, used for hit-testing.
class NoteLayout {
  final int index;
  final Rect rect;
  const NoteLayout(this.index, this.rect);
}

/// Custom painter that draws standard Western staff notation.
class StaffPainter extends CustomPainter {
  final Score score;
  final int? selectedIndex;
  final int cursorIndex;
  final int playbackIndex;

  /// After painting, this list contains the bounding rects of each note.
  final List<NoteLayout> noteLayouts = [];

  // Layout constants
  static const double staffTopMargin = 60.0;
  static const double lineSpacing = 14.0; // Distance between staff lines
  static const double noteSpacing = 50.0; // Horizontal space per beat
  static const double leftMargin = 80.0; // Space for clef + time sig
  static const double rightMargin = 40.0;
  static const double noteHeadWidth = 12.0;
  static const double noteHeadHeight = 10.0;

  StaffPainter({
    required this.score,
    this.selectedIndex,
    required this.cursorIndex,
    this.playbackIndex = -1,
  });

  /// Total width needed for the score.
  double get totalWidth {
    final beatsWidth = score.totalBeats * noteSpacing;
    return leftMargin + beatsWidth + noteSpacing * 2 + rightMargin;
  }

  @override
  void paint(Canvas canvas, Size size) {
    noteLayouts.clear();

    final staffLinePaint = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Top of the 5-line staff
    final staffTop = staffTopMargin;
    // Bottom of the 5-line staff (4 gaps × lineSpacing)
    final staffBottom = staffTop + 4 * lineSpacing;
    // Middle line (B4, line index 2)
    final middleLineY = staffTop + 2 * lineSpacing;

    // Draw 5 staff lines
    for (int i = 0; i < 5; i++) {
      final y = staffTop + i * lineSpacing;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        staffLinePaint,
      );
    }

    // Draw treble clef symbol
    _drawTrebleClef(canvas, 12, staffTop, staffBottom);

    // Draw time signature
    _drawTimeSignature(canvas, 50, staffTop, score.beatsPerMeasure, score.beatUnit);

    // Draw notes
    double beatOffset = 0;
    for (int i = 0; i < score.notes.length; i++) {
      final note = score.notes[i];
      final x = leftMargin + beatOffset * noteSpacing;
      
      if (note.isRest) {
        _drawRest(canvas, x, staffTop, middleLineY, note.duration, i);
      } else {
        _drawNote(canvas, x, staffTop, middleLineY, note, i);
      }
      
      beatOffset += note.duration.beats;
    }

    // Draw bar lines
    _drawBarLines(canvas, staffTop, staffBottom);

    // Draw cursor line
    final cursorX = leftMargin + _beatOffsetAtIndex(cursorIndex) * noteSpacing;
    final cursorPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(cursorX - 5, staffTop - 10),
      Offset(cursorX - 5, staffBottom + 10),
      cursorPaint,
    );
  }

  double _beatOffsetAtIndex(int index) {
    double offset = 0;
    for (int i = 0; i < index && i < score.notes.length; i++) {
      offset += score.notes[i].duration.beats;
    }
    return offset;
  }

  void _drawTrebleClef(Canvas canvas, double x, double staffTop, double staffBottom) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '𝄞',
        style: TextStyle(
          fontSize: lineSpacing * 6.5,
          color: const Color(0xFF333333),
          fontFamily: 'Bravura',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x, staffTop - lineSpacing * 1.8));
  }

  void _drawTimeSignature(Canvas canvas, double x, double staffTop, int top, int bottom) {
    final style = TextStyle(
      fontSize: lineSpacing * 2.2,
      fontWeight: FontWeight.w900,
      color: const Color(0xFF333333),
      height: 1.0,
    );

    // Top number
    final topPainter = TextPainter(
      text: TextSpan(text: '$top', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    topPainter.paint(canvas, Offset(x, staffTop - 2));

    // Bottom number
    final bottomPainter = TextPainter(
      text: TextSpan(text: '$bottom', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    bottomPainter.paint(canvas, Offset(x, staffTop + lineSpacing * 2 - 2));
  }

  void _drawNote(Canvas canvas, double x, double staffTop, double middleLineY,
      Note note, int index) {
    // Staff position: 0 = bottom line (E4), each step = half lineSpacing
    final pos = note.staffPosition;
    // Y coordinate: bottom line is at staffTop + 4*lineSpacing
    // Each position step moves up by lineSpacing/2
    final y = (staffTop + 4 * lineSpacing) - pos * (lineSpacing / 2);

    // Determine colors
    Color noteColor;
    if (index == playbackIndex) {
      noteColor = const Color(0xFF4CAF50); // Green during playback
    } else if (index == selectedIndex) {
      noteColor = const Color(0xFF2196F3); // Blue when selected
    } else {
      noteColor = const Color(0xFF333333); // Default black
    }

    final notePaint = Paint()
      ..color = noteColor
      ..style = (note.duration == NoteDuration.whole || note.duration == NoteDuration.half)
          ? PaintingStyle.stroke
          : PaintingStyle.fill
      ..strokeWidth = 2.0;

    // Draw ledger lines if needed
    _drawLedgerLines(canvas, x, staffTop, pos, noteColor);

    // Draw note head (ellipse)
    canvas.save();
    canvas.translate(x + noteHeadWidth / 2, y);
    canvas.rotate(-0.15); // Slight tilt like real notation
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: noteHeadWidth, height: noteHeadHeight),
      notePaint,
    );
    canvas.restore();

    // Store layout for hit testing
    noteLayouts.add(NoteLayout(
      index,
      Rect.fromCenter(
        center: Offset(x + noteHeadWidth / 2, y),
        width: noteHeadWidth + 16,
        height: noteHeadHeight + 16,
      ),
    ));

    // Draw stem (except for whole notes)
    if (note.duration != NoteDuration.whole) {
      final stemPaint = Paint()
        ..color = noteColor
        ..strokeWidth = 1.5;

      // Stem goes up if below middle line, down if above
      final stemUp = pos < 4; // Below middle line B4
      final stemLength = lineSpacing * 3.5;
      
      if (stemUp) {
        // Stem up: right side of note head, going up
        canvas.drawLine(
          Offset(x + noteHeadWidth, y),
          Offset(x + noteHeadWidth, y - stemLength),
          stemPaint,
        );
        // Draw flags for eighth and sixteenth
        _drawFlags(canvas, x + noteHeadWidth, y - stemLength, note.duration, noteColor, true);
      } else {
        // Stem down: left side of note head, going down
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + stemLength),
          stemPaint,
        );
        _drawFlags(canvas, x, y + stemLength, note.duration, noteColor, false);
      }
    }

    // Draw accidental
    if (note.accidental != Accidental.none) {
      final accPainter = TextPainter(
        text: TextSpan(
          text: note.accidental.symbol,
          style: TextStyle(fontSize: lineSpacing * 1.2, color: noteColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      accPainter.paint(canvas, Offset(x - accPainter.width - 4, y - accPainter.height / 2));
    }
  }

  void _drawLedgerLines(Canvas canvas, double x, double staffTop, int staffPos, Color color) {
    final ledgerPaint = Paint()
      ..color = color.withAlpha(179)
      ..strokeWidth = 1.0;

    // Ledger lines below staff (position < 0, at positions 0, -2, -4, ...)
    if (staffPos <= -1) {
      for (int p = -2; p >= staffPos; p -= 2) {
        final ly = (staffTop + 4 * lineSpacing) - p * (lineSpacing / 2);
        canvas.drawLine(
          Offset(x - 6, ly),
          Offset(x + noteHeadWidth + 6, ly),
          ledgerPaint,
        );
      }
    }

    // Ledger lines above staff (position > 8, at positions 10, 12, ...)
    if (staffPos >= 9) {
      for (int p = 10; p <= staffPos; p += 2) {
        final ly = (staffTop + 4 * lineSpacing) - p * (lineSpacing / 2);
        canvas.drawLine(
          Offset(x - 6, ly),
          Offset(x + noteHeadWidth + 6, ly),
          ledgerPaint,
        );
      }
    }

    // Middle C ledger line (position = -2, exactly at C4)
    if (staffPos == -2) {
      final ly = (staffTop + 4 * lineSpacing) - (-2) * (lineSpacing / 2);
      canvas.drawLine(
        Offset(x - 6, ly),
        Offset(x + noteHeadWidth + 6, ly),
        ledgerPaint,
      );
    }
  }

  void _drawFlags(Canvas canvas, double x, double y, NoteDuration duration,
      Color color, bool stemUp) {
    if (duration != NoteDuration.eighth && duration != NoteDuration.sixteenth) return;

    final flagPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final flagLength = lineSpacing * 2;
    final direction = stemUp ? 1.0 : -1.0;

    // Draw first flag
    final path = Path();
    path.moveTo(x, y);
    path.quadraticBezierTo(
      x + 8, y + direction * flagLength * 0.5,
      x + 4, y + direction * flagLength,
    );
    canvas.drawPath(path, flagPaint);

    // Draw second flag for sixteenth
    if (duration == NoteDuration.sixteenth) {
      final path2 = Path();
      path2.moveTo(x, y + direction * lineSpacing * 0.6);
      path2.quadraticBezierTo(
        x + 8, y + direction * (flagLength * 0.5 + lineSpacing * 0.6),
        x + 4, y + direction * (flagLength + lineSpacing * 0.6),
      );
      canvas.drawPath(path2, flagPaint);
    }
  }

  void _drawRest(Canvas canvas, double x, double staffTop, double middleLineY,
      NoteDuration duration, int index) {
    Color restColor;
    if (index == playbackIndex) {
      restColor = const Color(0xFF4CAF50);
    } else if (index == selectedIndex) {
      restColor = const Color(0xFF2196F3);
    } else {
      restColor = const Color(0xFF333333);
    }

    final restSymbol = switch (duration) {
      NoteDuration.whole => '𝄻',
      NoteDuration.half => '𝄼',
      NoteDuration.quarter => '𝄽',
      NoteDuration.eighth => '𝄾',
      NoteDuration.sixteenth => '𝄿',
    };

    final textPainter = TextPainter(
      text: TextSpan(
        text: restSymbol,
        style: TextStyle(fontSize: lineSpacing * 3, color: restColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(x, middleLineY - textPainter.height / 2),
    );

    // Store layout for hit testing
    noteLayouts.add(NoteLayout(
      index,
      Rect.fromCenter(
        center: Offset(x + textPainter.width / 2, middleLineY),
        width: textPainter.width + 16,
        height: lineSpacing * 4,
      ),
    ));
  }

  void _drawBarLines(Canvas canvas, double staffTop, double staffBottom) {
    if (score.notes.isEmpty) return;
    
    final barLinePaint = Paint()
      ..color = const Color(0xFF444444)
      ..strokeWidth = 1.5;

    double beatOffset = 0;
    for (int i = 0; i < score.notes.length; i++) {
      beatOffset += score.notes[i].duration.beats;

      // Draw bar line at measure boundaries
      if ((beatOffset % score.beatsPerMeasure).abs() < 0.001 && i < score.notes.length - 1) {
        final x = leftMargin + beatOffset * noteSpacing;
        canvas.drawLine(
          Offset(x - noteSpacing / 4, staffTop),
          Offset(x - noteSpacing / 4, staffBottom),
          barLinePaint,
        );
      }
    }

    // Final bar line at end
    final endX = leftMargin + beatOffset * noteSpacing;
    canvas.drawLine(
      Offset(endX + 5, staffTop),
      Offset(endX + 5, staffBottom),
      barLinePaint..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(StaffPainter oldDelegate) => true;
}
