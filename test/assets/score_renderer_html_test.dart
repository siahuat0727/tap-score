import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('score renderer forwards editing shortcuts from the iframe', () {
    final html = File('assets/html/score_renderer.html').readAsStringSync();

    expect(html, contains('const forwardedCodes = ['));
    expect(html, contains("'KeyD'"));
    expect(html, contains("'KeyL'"));
    expect(html, contains("'Backquote'"));
    expect(html, contains("'Enter'"));
    expect(html, contains("'NumpadEnter'"));
    expect(html, contains("'Digit1'"));
    expect(html, contains("'Digit6'"));
    expect(html, contains("'Digit7'"));
    expect(html, contains("'Digit8'"));
    expect(html, contains("'Digit9'"));
    expect(html, contains("code: e.code"));
  });

  test(
    'score renderer includes thirty-second durations and slur rendering',
    () {
      final html = File('assets/html/score_renderer.html').readAsStringSync();

      expect(html, contains("dur: '32'"));
      expect(html, contains('source.slurToNext'));
      expect(html, contains('new Curve('));
    },
  );

  test('score renderer handles the inline rhythm overlay payload', () {
    final html = File('assets/html/score_renderer.html').readAsStringSync();

    expect(html, contains('function _drawRhythmOverlay('));
    expect(html, contains('function _buildRhythmMeasureSegments('));
    expect(html, contains('function _drawRhythmErrorLabels('));
    expect(html, contains('const RHYTHM_ERROR_LABEL_THRESHOLD_BEATS = 0.02;'));
    expect(html, contains('rhythmTest.showExpectedEvents'));
    expect(html, contains('rhythmTest.liveTapEvents'));
    expect(html, contains('rhythmTest.resultTapEvents'));
    expect(html, contains('rhythmTest.playheadTimeSeconds'));
    expect(html, contains('rhythmTest.countInDurationSeconds'));
    expect(html, contains('measureBoundaryTimesSeconds'));
    expect(html, contains('rhythmTest.pulsesPerMeasure'));
    expect(html, contains('startX: measureRenderData[0].contentStartX,'));
    expect(html, contains('const timeZeroX = measureRenderData[0].contentStartX;'));
    expect(html, contains('const leadInStartX = measureRenderData[0].startX;'));
    expect(html, contains('const playhead = document.createElementNS(ns, \'line\');'));
    expect(html, contains('const clampedLeadInTime = Math.max(timeSeconds, -countInDurationSeconds);'));
    expect(html, contains('transform',));
    expect(html, contains('rotate(-60'));
    expect(html, contains("text.setAttribute('text-anchor', 'middle');"));
    expect(html, contains('function _xForRhythmTime('));
    expect(html, contains('leadInStartX,'));
    expect(html, contains('timeZeroX,'));
    expect(html, isNot(contains('const progressX = _xForRhythmTime(')));
    expect(html, isNot(contains('function _measureSegmentWidth(')));
    expect(html, isNot(contains('labelBands')));
    expect(html, isNot(contains('bandRightEdges')));
    expect(html, isNot(contains('_approximateRotatedLabelWidth')));
    expect(html, isNot(contains('const leadInStartX = measureRenderData[0].startX;\n      const timeZeroX = measureRenderData[0].contentStartX;\n      const leadInWidth = Math.max(timeZeroX - leadInStartX, 0);')));
    expect(html, isNot(contains('noteCenterByIndex')));
  });
}
