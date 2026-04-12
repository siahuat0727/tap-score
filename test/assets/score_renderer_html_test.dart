import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

dynamic _runRendererHookForTest(String hookName, Map<String, dynamic> payload) {
  final html = File('assets/html/score_renderer.html').readAsStringSync();
  final script = '''
const html = process.env.RENDERER_HTML;
const hookName = process.env.RENDERER_HOOK_NAME;
const payload = JSON.parse(process.env.RENDERER_PAYLOAD);
const scriptMatches = [...html.matchAll(/<script(?:[^>]*)>([\\s\\S]*?)<\\/script>/g)];
if (scriptMatches.length === 0) {
  throw new Error('No inline renderer script found');
}
const inlineScript = scriptMatches[scriptMatches.length - 1][1];

global.window = {
  addEventListener() {},
  parent: null,
};
global.document = {
  getElementById() { return {}; },
  createElement() {
    return {
      style: {},
      appendChild() {},
      remove() {},
      querySelectorAll() { return []; },
    };
  },
  addEventListener() {},
  body: {
    appendChild() {},
    removeChild() {},
  },
};
global.Vex = {
  Flow: {
    Renderer: function Renderer() {},
    Stave: function Stave() {},
    StaveNote: function StaveNote() {},
    Voice: function Voice() {},
    Formatter: function Formatter() {},
    Accidental: function Accidental() {},
    KeySignature: function KeySignature() {},
    TimeSignature: function TimeSignature() {},
    Barline: {},
    StaveConnector: function StaveConnector() {},
    Beam: function Beam() {},
    Fraction: function Fraction() {},
    StaveTie: function StaveTie() {},
    Tuplet: function Tuplet() {},
    Dot: function Dot() {},
    Curve: function Curve() {},
  },
};

eval(inlineScript);
process.stdout.write(JSON.stringify(window.__tapScoreTestHooks[hookName](payload)));
''';

  final result = Process.runSync(
    'node',
    ['-e', script],
    environment: {
      ...Platform.environment,
      'RENDERER_HTML': html,
      'RENDERER_HOOK_NAME': hookName,
      'RENDERER_PAYLOAD': jsonEncode(payload),
    },
  );

  expect(result.exitCode, 0, reason: result.stderr.toString());
  return jsonDecode(result.stdout as String);
}

List<Map<String, dynamic>> _mapListFromDynamic(dynamic value) {
  final decoded = value as List<Object?>;
  return decoded
      .cast<Map<Object?, Object?>>()
      .map(
        (item) =>
            item.map((key, itemValue) => MapEntry(key as String, itemValue)),
      )
      .toList();
}

List<Map<String, dynamic>> _splitRendererNotesForTest(
  Map<String, dynamic> payload,
) {
  return _mapListFromDynamic(
    _runRendererHookForTest('splitAndGroupForTest', payload),
  );
}

List<String> _rhythmPulseAccentPatternForTest({
  required int beatsPerMeasure,
  required int beatUnit,
}) {
  final decoded =
      _runRendererHookForTest('rhythmPulseAccentPatternForTest', {
            'beatsPerMeasure': beatsPerMeasure,
            'beatUnit': beatUnit,
          })
          as List<Object?>;
  return decoded.cast<String>();
}

List<Map<String, dynamic>> _buildRhythmPulseDescriptorsForTest(
  Map<String, dynamic> payload,
) {
  return _mapListFromDynamic(
    _runRendererHookForTest('buildRhythmPulseDescriptorsForTest', payload),
  );
}

int? _activeRhythmPulseIndexForTest({
  required double playheadTimeSeconds,
  required List<Map<String, dynamic>> pulseDescriptors,
  required String overlayPhase,
}) {
  final result = _runRendererHookForTest('activeRhythmPulseIndexForTest', {
    'playheadTimeSeconds': playheadTimeSeconds,
    'pulseDescriptors': pulseDescriptors,
    'overlayPhase': overlayPhase,
  });
  return result as int?;
}

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
    expect(html, contains('function _rhythmPulseAccentPattern('));
    expect(html, contains('function _buildRhythmPulseDescriptors('));
    expect(html, contains('function _activeRhythmPulseIndex('));
    expect(html, contains('function _drawRhythmPulseRail('));
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
      contains('const pulseDescriptors = _buildRhythmPulseDescriptors('),
    );
    expect(html, contains('const activePulseIndex = _activeRhythmPulseIndex('));
    expect(html, contains('_drawRhythmPulseRail('));
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

  test('rhythm pulse accent pattern uses 4/4 grouping', () {
    expect(_rhythmPulseAccentPatternForTest(beatsPerMeasure: 4, beatUnit: 4), [
      'strong',
      'weak',
      'medium',
      'weak',
    ]);
  });

  test('rhythm pulse accent pattern uses 3/4 grouping', () {
    expect(_rhythmPulseAccentPatternForTest(beatsPerMeasure: 3, beatUnit: 4), [
      'strong',
      'weak',
      'weak',
    ]);
  });

  test(
    'rhythm pulse accent pattern uses 6/8 subdivision with grouped heads',
    () {
      expect(
        _rhythmPulseAccentPatternForTest(beatsPerMeasure: 6, beatUnit: 8),
        ['strong', 'weak', 'weak', 'medium', 'weak', 'weak'],
      );
    },
  );

  test('rhythm pulse accent pattern falls back for unsupported odd meters', () {
    expect(_rhythmPulseAccentPatternForTest(beatsPerMeasure: 5, beatUnit: 8), [
      'strong',
      'weak',
      'weak',
      'weak',
      'weak',
    ]);
  });

  test(
    'rhythm pulse descriptors include count-in and body pulses on one rail',
    () {
      final descriptors = _buildRhythmPulseDescriptorsForTest({
        'measureSegments': [
          {'startX': 100, 'endX': 220, 'durationSeconds': 4},
          {'startX': 220, 'endX': 340, 'durationSeconds': 4},
        ],
        'measureBoundaryTimesSeconds': [0, 4, 8],
        'pulseDurationSeconds': 1,
        'countInDurationSeconds': 4,
        'totalDurationSeconds': 8,
        'leadInStartX': 40,
        'timeZeroX': 100,
        'beatsPerMeasure': 4,
        'beatUnit': 4,
      });

      expect(descriptors, hasLength(12));
      expect(
        descriptors.take(4).map((pulse) => pulse['accentClass']).toList(),
        ['strong', 'weak', 'medium', 'weak'],
      );
      expect(descriptors.take(4).map((pulse) => pulse['isCountIn']).toList(), [
        true,
        true,
        true,
        true,
      ]);
      expect(
        descriptors.take(4).map((pulse) => pulse['measureIndex']).toList(),
        [-1, -1, -1, -1],
      );
      expect(
        descriptors
            .skip(4)
            .take(4)
            .map((pulse) => pulse['accentClass'])
            .toList(),
        ['strong', 'weak', 'medium', 'weak'],
      );
      expect(descriptors[0]['x'], closeTo(40, 0.001));
      expect(descriptors[3]['x'], closeTo(85, 0.001));
      expect(descriptors[4]['x'], closeTo(100, 0.001));
      expect(descriptors[8]['x'], closeTo(220, 0.001));
    },
  );

  test(
    'active rhythm pulse index handles count-in, live playback, and result mode',
    () {
      final descriptors = _buildRhythmPulseDescriptorsForTest({
        'measureSegments': [
          {'startX': 100, 'endX': 220, 'durationSeconds': 4},
          {'startX': 220, 'endX': 340, 'durationSeconds': 4},
        ],
        'measureBoundaryTimesSeconds': [0, 4, 8],
        'pulseDurationSeconds': 1,
        'countInDurationSeconds': 4,
        'totalDurationSeconds': 8,
        'leadInStartX': 40,
        'timeZeroX': 100,
        'beatsPerMeasure': 4,
        'beatUnit': 4,
      });

      expect(
        _activeRhythmPulseIndexForTest(
          playheadTimeSeconds: -1.2,
          pulseDescriptors: descriptors,
          overlayPhase: 'live',
        ),
        2,
      );
      expect(
        _activeRhythmPulseIndexForTest(
          playheadTimeSeconds: 5.4,
          pulseDescriptors: descriptors,
          overlayPhase: 'live',
        ),
        9,
      );
      expect(
        _activeRhythmPulseIndexForTest(
          playheadTimeSeconds: 5.4,
          pulseDescriptors: descriptors,
          overlayPhase: 'result',
        ),
        isNull,
      );
    },
  );

  test(
    'simple-meter split heuristic preserves the following eighth-note beam pair',
    () {
      final displayNotes = _splitRendererNotesForTest({
        'beatsPerMeasure': 4,
        'beatUnit': 4,
        'notes': [
          {'midi': 0, 'beats': 0.5, 'isRest': true, 'tripletGroupId': null},
          {'midi': 64, 'beats': 2.0, 'isRest': false, 'tripletGroupId': null},
          {'midi': 65, 'beats': 0.5, 'isRest': false, 'tripletGroupId': null},
          {'midi': 67, 'beats': 1.0, 'isRest': false, 'tripletGroupId': null},
        ],
      });

      expect(displayNotes, hasLength(5));
      expect(displayNotes.map((note) => note['beats']).toList(), [
        0.5,
        1.5,
        0.5,
        0.5,
        1.0,
      ]);
      expect(displayNotes.map((note) => note['globalIndex']).toList(), [
        0,
        1,
        1,
        2,
        3,
      ]);

      expect(displayNotes[1]['duration'], 'q');
      expect(displayNotes[1]['isDotted'], isTrue);
      expect(displayNotes[1]['tieStart'], isTrue);
      expect(displayNotes[1]['tieEnd'], isFalse);

      expect(displayNotes[2]['duration'], '8');
      expect(displayNotes[2]['isDotted'], isFalse);
      expect(displayNotes[2]['tieStart'], isFalse);
      expect(displayNotes[2]['tieEnd'], isTrue);

      expect(displayNotes[3]['beats'], 0.5);
      expect(displayNotes[3]['tieStart'], isFalse);
      expect(displayNotes[3]['tieEnd'], isFalse);

      expect(displayNotes[4]['duration'], 'q');
      expect(displayNotes[1]['beats'], isNot(0.5));
      expect(displayNotes[2]['beats'], isNot(1.5));
    },
  );
}
