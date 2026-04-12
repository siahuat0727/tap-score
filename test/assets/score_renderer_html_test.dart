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
    expect(html, contains("repeat: e.repeat"));
  });

  test('score renderer reserves a larger score header for title and tempo', () {
    final html = File('assets/html/score_renderer.html').readAsStringSync();

    expect(
      html,
      contains("const headerHeight = hasTitle ? 56 : hasTempo ? 38 : 0;"),
    );
    expect(html, contains("titleEl.setAttribute('font-size', '24');"));
    expect(html, contains("tempoEl.setAttribute('font-size', '18');"));
    expect(html, contains("const tempoY = hasTitle ? 62 : staveTop - 18;"));
  });

  test('flutter score view does not draw a duplicate tempo overlay', () {
    final source = File(
      'lib/widgets/score_view_widget.dart',
    ).readAsStringSync();

    expect(source, contains("key: const ValueKey('score-view-surface')"));
    expect(
      source,
      isNot(
        contains("Text(\n                '♩ = \${notifier.score.bpm.round()}'"),
      ),
    );
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

  test('score renderer uses payload clef data for drawing and hit testing', () {
    final html = File('assets/html/score_renderer.html').readAsStringSync();
    final source = File(
      'lib/widgets/score_view_widget.dart',
    ).readAsStringSync();

    expect(html, contains('function measureFirstMeasureLeadingWidth(clef,'));
    expect(html, contains("measurementStave.addClef(clef);"));
    expect(html, contains("stave.addClef(clef);"));
    expect(
      html,
      contains(
        "new StaveNote({ clef, keys: [restAnchorPitch], duration: dur + 'r' })",
      ),
    );
    expect(
      html,
      contains(
        "new StaveNote({ clef, keys: [pitch.toLowerCase()], duration: dur })",
      ),
    );
    expect(html, contains("if (selectionKind === 'clef') {"));
    expect(html, contains("const clefEl = svg.querySelector('.vf-clef');"));
    expect(html, contains("_sendMessage({ type: 'clefTap' });"));
    expect(html, isNot(contains("addClef('treble')")));
    expect(source, contains("'clef': clef.vexflowName"));
    expect(source, contains("'restAnchorPitch': clef.restAnchorPitch"));
    expect(source, contains("case 'clefTap':"));
  });

  test(
    'web score renderer disables pointer events for non-interactive views',
    () {
      final source = File(
        'lib/widgets/score_renderer_web.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          "..pointerEvents = widget.pointerInputEnabled ? 'auto' : 'none';",
        ),
      );
      expect(
        source,
        contains('void didUpdateWidget(covariant _WebScoreRenderer oldWidget)'),
      );
      expect(source, contains('_syncPointerInputState();'));
    },
  );

  test('score renderer handles the inline rhythm overlay payload', () {
    final html = File('assets/html/score_renderer.html').readAsStringSync();

    expect(html, contains('function _drawRhythmOverlay('));
    expect(html, contains('function _buildRhythmMeasureSegments('));
    expect(html, contains('function _drawRhythmErrorLabels('));
    expect(html, contains("const overlayPhase = rhythmTest.phase || 'idle';"));
    expect(html, contains("const showsPlayhead = overlayPhase === 'live';"));
    expect(
      html,
      contains("const showsResultOverlay = overlayPhase === 'result';"),
    );
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
    expect(html, contains('for (const tap of rhythmTest.liveTapEvents) {'));
    expect(html, contains('for (const tap of rhythmTest.resultTapEvents) {'));
    expect(html, contains('if (!showsResultOverlay) {'));
    expect(html, contains('if (showsPlayhead) {'));
    expect(html, isNot(contains('rhythmTest.showExpectedEvents')));
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
    expect(html, contains("group.setAttribute(\n        'transform',"));
    expect(
      html,
      contains("let rhythmInspectionState = { key: null, pinned: false };"),
    );
    expect(html, contains('function _setRhythmInspectionContext(nextContext)'));
    expect(
      html,
      contains(
        "if (rhythmInspectionState.pinned && rhythmInspectionState.key === inspectKey) {",
      ),
    );
    expect(
      html,
      contains("_setRhythmInspectState({ key: inspectKey, pinned: true });"),
    );
    expect(
      html,
      contains("_setRhythmInspectState({ key: inspectKey, pinned: false });"),
    );
    expect(html, contains("context.tooltipGroup = group;"));
    expect(html, contains("const hitRadius = 14;"));
    expect(html, contains("const hit = document.createElementNS(ns, 'rect');"));
    expect(html, contains("hit.setAttribute('x', x - hitRadius);"));
    expect(html, contains("hit.setAttribute('y', y - hitRadius);"));
    expect(html, contains("hit.setAttribute('width', hitRadius * 2);"));
    expect(html, contains("hit.setAttribute('height', hitRadius * 2);"));
    expect(html, contains("hit.setAttribute('fill', 'rgba(0, 0, 0, 0)');"));
    expect(html, contains("hit.setAttribute('stroke', 'none');"));
    expect(
      html,
      isNot(contains("const pointer = document.createElementNS(ns, 'path');")),
    );
    expect(html, isNot(contains('pointer.setAttribute(')));
    expect(html, contains('function _xForRhythmTime('));
    expect(html, contains('leadInStartX,'));
    expect(html, contains('timeZeroX,'));
    expect(html, isNot(contains('const progressX = _xForRhythmTime(')));
    expect(html, isNot(contains('function _measureSegmentWidth(')));
    expect(html, isNot(contains('labelBands')));
    expect(html, isNot(contains('bandRightEdges')));
    expect(html, isNot(contains('_approximateRotatedLabelWidth')));
    expect(html, isNot(contains('Rhythm test result')));
    expect(html, isNot(contains('lockedRhythmInspectKey')));
    expect(html, isNot(contains('hoveredRhythmInspectKey')));
    expect(html, isNot(contains('renderScore(currentData);')));
    expect(html, isNot(contains("point.setAttribute('stroke', '#ffffff');")));
    expect(html, isNot(contains("point.setAttribute('stroke-width', '1.5');")));
    expect(
      html,
      isNot(contains("const hit = document.createElementNS(ns, 'circle');")),
    );
    expect(html, isNot(contains("hit.setAttribute('r', '14');")));
    expect(html, isNot(contains("hit.setAttribute('fill', 'transparent');")));
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
