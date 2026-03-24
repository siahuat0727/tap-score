import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('score renderer forwards editing shortcuts from the iframe', () {
    final html = File('assets/html/score_renderer.html').readAsStringSync();

    expect(
      html,
      contains('if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing)'),
    );
    expect(
      html,
      contains("['Shift', 'Control', 'Alt', 'Meta'].includes(e.key)"),
    );
    expect(html, contains('const isPrintableKey = e.key.length === 1;'));
    expect(html, contains("'ArrowLeft'"));
    expect(html, contains("'NumpadEnter'"));
    expect(html, isNot(contains('const forwardedCodes = [')));
    expect(html, contains('key: e.key'));
    expect(html, contains("code: e.code"));
  });

  test(
    'score renderer includes thirty-second durations and slur rendering',
    () {
      final html = File('assets/html/score_renderer.html').readAsStringSync();

      expect(html, contains("dur: '32'"));
      expect(html, contains('source.slurToNext'));
      expect(
        html,
        contains('const isTieLikeConnection = source.midi === target.midi;'),
      );
      expect(html, contains('new StaveTie({'));
      expect(html, contains('new Curve('));
    },
  );

  test(
    'web score renderer disables pointer events for non-interactive views',
    () {
      final source = File(
        'lib/widgets/score_renderer_web.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("..pointerEvents = widget.interactive ? 'auto' : 'none';"),
      );
    },
  );

  test('score renderer handles the inline rhythm overlay payload', () {
    final html = File('assets/html/score_renderer.html').readAsStringSync();

    expect(html, contains('function _drawRhythmOverlay('));
    expect(html, contains('function _buildRhythmMeasureSegments('));
    expect(html, contains('function _drawRhythmErrorLabels('));
    expect(
      html,
      contains(
        'const errorLabelThresholdBeats = rhythmTest.errorLabelThresholdBeats;',
      ),
    );
    expect(
      html,
      contains(
        'const largeErrorThresholdBeats = rhythmTest.largeErrorThresholdBeats;',
      ),
    );
    expect(html, contains('rhythmTest.showExpectedEvents'));
    expect(html, contains('rhythmTest.liveTapEvents'));
    expect(html, contains('rhythmTest.resultTapEvents'));
    expect(html, contains('rhythmTest.largeErrorNoteIndices'));
    expect(html, contains('rhythmTest.missedExpectedNoteIndices'));
    expect(html, contains('rhythmTest.playheadTimeSeconds'));
    expect(html, contains('rhythmTest.countInDurationSeconds'));
    expect(html, contains('measureBoundaryTimesSeconds'));
    expect(html, contains('function _drawRhythmResultNoteHighlights('));
    expect(
      html,
      contains('const measureSegments = _buildRhythmMeasureSegments('),
    );
    expect(
      html,
      contains(
        'Math.round(measure.durationSeconds / rhythmTest.pulseDurationSeconds)',
      ),
    );
    expect(html, contains('for (let beat = 1; beat < beatCount; beat++)'));
    expect(html, contains('durationSeconds:'));
    expect(
      html,
      contains('const timeZeroX = measureRenderData[0].contentStartX;'),
    );
    expect(html, contains('const leadInStartX = measureRenderData[0].startX;'));
    expect(
      html,
      contains("const playhead = document.createElementNS(ns, 'line');"),
    );
    expect(
      html,
      contains(
        'const clampedLeadInTime = Math.max(timeSeconds, -countInDurationSeconds);',
      ),
    );
    expect(html, contains('transform'));
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
    expect(html, isNot(contains('Rhythm test result')));
    expect(
      html,
      isNot(
        contains(
          'const leadInStartX = measureRenderData[0].startX;\n      const timeZeroX = measureRenderData[0].contentStartX;\n      const leadInWidth = Math.max(timeZeroX - leadInStartX, 0);',
        ),
      ),
    );
    expect(html, contains("point.setAttribute('r', '3.5');"));
    expect(html, isNot(contains('noteCenterByIndex')));
  });
}
