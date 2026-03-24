import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../rhythm_test/rhythm_test_models.dart';
import '../theme/app_colors.dart';

class RhythmTestTimeline extends StatelessWidget {
  const RhythmTestTimeline({
    required this.timeline,
    required this.tapEvents,
    required this.result,
    required this.elapsedRunSeconds,
    super.key,
  });

  final RhythmTimeline timeline;
  final List<TapInputEvent> tapEvents;
  final RhythmTestResult? result;
  final double elapsedRunSeconds;

  @override
  Widget build(BuildContext context) {
    final latestTapSeconds = tapEvents.isEmpty
        ? 0.0
        : tapEvents.last.timeSeconds;
    final earliestTapSeconds = tapEvents.isEmpty
        ? 0.0
        : tapEvents.map((tap) => tap.timeSeconds).reduce(math.min);
    final displayStartSeconds = math.min(
      0.0,
      math.min(earliestTapSeconds, -timeline.matchingWindowSeconds),
    );
    final displayEndSeconds = math.max(
      timeline.totalDurationSeconds + timeline.matchingWindowSeconds,
      latestTapSeconds,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.timelineBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.timelineBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 240,
          width: double.infinity,
          child: CustomPaint(
            painter: _RhythmTimelinePainter(
              timeline: timeline,
              tapEvents: tapEvents,
              result: result,
              displayStartSeconds: displayStartSeconds,
              displayEndSeconds: displayEndSeconds <= displayStartSeconds
                  ? displayStartSeconds + 1
                  : displayEndSeconds,
              elapsedRunSeconds: elapsedRunSeconds,
            ),
          ),
        ),
      ),
    );
  }
}

class _RhythmTimelinePainter extends CustomPainter {
  const _RhythmTimelinePainter({
    required this.timeline,
    required this.tapEvents,
    required this.result,
    required this.displayStartSeconds,
    required this.displayEndSeconds,
    required this.elapsedRunSeconds,
  });

  final RhythmTimeline timeline;
  final List<TapInputEvent> tapEvents;
  final RhythmTestResult? result;
  final double displayStartSeconds;
  final double displayEndSeconds;
  final double elapsedRunSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    const leftInset = 72.0;
    const rightInset = 20.0;
    const topY = 72.0;
    const bottomY = 176.0;

    final trackPaint = Paint()
      ..color = AppColors.timelineTrack
      ..strokeWidth = 2;
    final measurePaint = Paint()
      ..color = AppColors.timelineMeasure
      ..strokeWidth = 1.4;
    final beatPaint = Paint()
      ..color = AppColors.timelineBeat
      ..strokeWidth = 1;
    final activeWindowPaint = Paint()..color = const Color(0x142196F3);

    final usableWidth = size.width - leftInset - rightInset;
    final left = leftInset;
    final right = left + usableWidth;
    final zeroX = _xForTime(0, left, usableWidth);
    final progressRightX = _xForTime(elapsedRunSeconds, left, usableWidth);

    if (progressRightX > zeroX) {
      canvas.drawRect(
        Rect.fromLTRB(zeroX, 36, progressRightX, 206),
        activeWindowPaint,
      );
    }

    for (
      var time = 0.0;
      time <= timeline.totalDurationSeconds + 0.001;
      time += timeline.pulseDurationSeconds
    ) {
      final x = _xForTime(time, left, usableWidth);
      canvas.drawLine(Offset(x, 28), Offset(x, 208), beatPaint);
    }

    for (final boundary in timeline.measureBoundaryTimesSeconds) {
      final x = _xForTime(boundary, left, usableWidth);
      canvas.drawLine(Offset(x, 28), Offset(x, 208), measurePaint);
    }

    canvas.drawLine(Offset(left, topY), Offset(right, topY), trackPaint);
    canvas.drawLine(Offset(left, bottomY), Offset(right, bottomY), trackPaint);

    _paintLabel(canvas, const Offset(12, topY - 12), 'Score');
    _paintLabel(canvas, const Offset(24, bottomY - 12), 'You');

    final matchedExpectedIds = <int>{};
    final matchedTapIds = <int>{};
    if (result != null) {
      for (final pair in result!.matchedPairs) {
        matchedExpectedIds.add(pair.expected.id);
        matchedTapIds.add(pair.tap.id);

        final x1 = _xForTime(pair.expected.timeSeconds, left, usableWidth);
        final x2 = _xForTime(pair.tap.timeSeconds, left, usableWidth);
        final ratio =
            (pair.absoluteErrorSeconds / timeline.matchingWindowSeconds)
                .clamp(0, 1)
                .toDouble();
        final lineColor = Color.lerp(
          AppColors.timelineMatchGood,
          AppColors.timelineMatchWarn,
          ratio,
        )!;
        final linePaint = Paint()
          ..color = lineColor
          ..strokeWidth = 3;
        canvas.drawLine(Offset(x1, topY), Offset(x2, bottomY), linePaint);

        final beatError = pair.errorSeconds / timeline.pulseDurationSeconds;
        _paintErrorLabel(
          canvas,
          Offset((x1 + x2) / 2 - 26, (topY + bottomY) / 2 - 12),
          '${beatError >= 0 ? '+' : ''}${beatError.toStringAsFixed(2)} beat',
          lineColor,
        );
      }
    }

    if (result != null) {
      for (final event in timeline.expectedEvents) {
        final matched = matchedExpectedIds.contains(event.id);
        _paintEvent(
          canvas,
          Offset(_xForTime(event.timeSeconds, left, usableWidth), topY),
          matched ? AppColors.timelineMatchedScore : AppColors.timelineUnmatchedScore,
        );
      }
    }

    for (final tap in tapEvents) {
      final matched = matchedTapIds.contains(tap.id);
      _paintEvent(
        canvas,
        Offset(_xForTime(tap.timeSeconds, left, usableWidth), bottomY),
        matched
            ? AppColors.timelineMatchedTap
            : result == null
            ? const Color(0xFF5D4037)
            : AppColors.statusWarning,
      );
    }
  }

  void _paintEvent(Canvas canvas, Offset center, Color color) {
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 8, fill);
    canvas.drawCircle(center, 8, stroke);
  }

  void _paintLabel(Canvas canvas, Offset offset, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.timelineLabel,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _paintErrorLabel(
    Canvas canvas,
    Offset offset,
    String text,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          backgroundColor: AppColors.timelineErrorBackground,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  double _xForTime(double timeSeconds, double left, double usableWidth) {
    final ratio =
        ((timeSeconds - displayStartSeconds) /
                (displayEndSeconds - displayStartSeconds))
            .clamp(0, 1);
    return left + usableWidth * ratio;
  }

  @override
  bool shouldRepaint(_RhythmTimelinePainter oldDelegate) {
    return timeline != oldDelegate.timeline ||
        tapEvents != oldDelegate.tapEvents ||
        result != oldDelegate.result ||
        displayStartSeconds != oldDelegate.displayStartSeconds ||
        displayEndSeconds != oldDelegate.displayEndSeconds ||
        elapsedRunSeconds != oldDelegate.elapsedRunSeconds;
  }
}
