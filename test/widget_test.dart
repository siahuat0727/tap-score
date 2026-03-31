import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_score/main.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/key_signature.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';
import 'package:tap_score/screens/score_editor_screen.dart';
import 'package:tap_score/services/preset_score_repository.dart';
import 'package:tap_score/services/score_library_repository.dart';
import 'package:tap_score/state/score_notifier.dart';
import 'package:tap_score/theme/app_colors.dart';
import 'package:tap_score/widgets/duration_selector.dart';
import 'package:tap_score/widgets/piano_keyboard.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'helpers/fake_webview_platform.dart';

BoxDecoration _buttonDecoration(WidgetTester tester, Key key) {
  final finder = find.descendant(
    of: find.byKey(key),
    matching: find.byType(AnimatedContainer),
  );
  return tester.widget<AnimatedContainer>(finder).decoration! as BoxDecoration;
}

Color _borderColor(BoxDecoration decoration) {
  return (decoration.border! as Border).top.color;
}

InkWell _buttonInkWell(WidgetTester tester, Key key) {
  final finder = find.descendant(
    of: find.byKey(key),
    matching: find.byType(InkWell),
  );
  return tester.widget<InkWell>(finder);
}

DurationSelector _buildDurationSelector() {
  return DurationSelector(
    onRhythmTestTap: () {},
    rhythmTestEnabled: true,
    rhythmTestActive: false,
  );
}

Widget _buildModifierAlignmentGolden() {
  return ChangeNotifierProvider(
    create: (_) => ScoreNotifier(),
    child: MaterialApp(
      home: Material(
        color: const Color(0xFFFBF6EE),
        child: Center(
          child: RepaintBoundary(
            key: const ValueKey('modifier-alignment-golden'),
            child: SizedBox(
              width: 281,
              height: 64,
              child: ClipRect(
                child: Transform.translate(
                  offset: const Offset(-224, 0),
                  child: DurationSelector(
                    onRhythmTestTap: () {},
                    rhythmTestEnabled: true,
                    rhythmTestActive: false,
                    showRhythmTestButton: false,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

TapScoreApp _buildTestApp({
  List<PresetScoreEntry> presets = const [],
  ScoreLibrarySnapshot? snapshot,
}) {
  return TapScoreApp(
    presetScoreRepository: _WidgetPresetScoreRepository(presets),
    scoreLibraryRepository: _WidgetMemoryScoreLibraryRepository(snapshot),
  );
}

Future<BuildContext> _openBlankEditor(
  WidgetTester tester, {
  List<PresetScoreEntry> presets = const [],
  ScoreLibrarySnapshot? snapshot,
}) async {
  await tester.pumpWidget(
    _buildTestApp(presets: presets, snapshot: snapshot),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('launch-new-blank-card')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return tester.element(find.byType(ScoreEditorScreen));
}

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  testWidgets('app launches to the lightweight home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    expect(find.byType(ScoreEditorScreen), findsNothing);
    expect(find.byKey(const ValueKey('launch-new-blank-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('launch-preset-card')), findsOneWidget);
  });

  testWidgets('home blank entry navigates to a blank editor draft', (
    WidgetTester tester,
  ) async {
    final context = await _openBlankEditor(tester);
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);

    expect(find.byType(ScoreEditorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('save-score-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('load-score-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-score-button')), findsOneWidget);
    expect(notifier.score.notes, isEmpty);
    expect(notifier.activePresetId, isNull);
  });

  testWidgets('home preset entry opens picker and initializes preset draft', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        presets: [
          PresetScoreEntry(
            id: 'preset-1',
            name: 'Triplet Study',
            assetPath: 'assets/presets/triplet_study.json',
            score: Score(
              notes: const [Note(midi: 67, duration: NoteDuration.quarter)],
              bpm: 96,
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('launch-preset-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('launch-preset-modal')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('preset-option-preset-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final context = tester.element(find.byType(ScoreEditorScreen));
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);
    expect(notifier.activePresetId, 'preset-1');
    expect(notifier.currentScoreLabel, 'Triplet Study');
    expect(notifier.score.notes.single.midi, 67);
  });

  testWidgets('floating actions overlay the score stage without using a row', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    final saveRect = tester.getRect(
      find.byKey(const ValueKey('save-score-button')),
    );
    final floatingRect = tester.getRect(
      find.byKey(const ValueKey('compose-floating-actions')),
    );
    final scoreRect = tester.getRect(
      find.byKey(const ValueKey('score-view-surface')),
    );
    final toolbarRect = tester.getRect(
      find.byKey(const ValueKey('compose-toolbar')),
    );

    expect(find.byKey(const ValueKey('compose-score-stage')), findsOneWidget);
    expect(saveRect.top, greaterThan(scoreRect.top));
    expect(saveRect.right, lessThan(scoreRect.right));
    expect(floatingRect.width, lessThan(scoreRect.width / 2));
    expect(floatingRect.bottom, lessThan(toolbarRect.top));
  });

  testWidgets('compose toolbar shows playback and signature controls inline', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('compose-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-play-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('compose-time-signature')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('compose-key-signature')), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-tempo')), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-rhythm-test')), findsOneWidget);
    expect(find.byKey(const ValueKey('rest-tool')), findsOneWidget);
    expect(find.byTooltip('Rhythm Test'), findsOneWidget);

    final playRect = tester.getRect(
      find.byKey(const ValueKey('compose-play-button')),
    );
    final restRect = tester.getRect(find.byKey(const ValueKey('rest-tool')));
    final rhythmRect = tester.getRect(
      find.byKey(const ValueKey('compose-rhythm-test')),
    );
    final toolbarRect = tester.getRect(
      find.byKey(const ValueKey('compose-toolbar')),
    );

    expect(playRect.left - toolbarRect.left, lessThan(24));
    expect(playRect.left, lessThan(restRect.left));
    expect(toolbarRect.right - rhythmRect.right, lessThan(24));
  });

  testWidgets('modifier tools use the same baseline-aligned glyph slot', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
      ),
    );
    await tester.pump();

    final dotGlyphSize = tester.getSize(
      find.byKey(const ValueKey('dot-tool-glyph-box')),
    );
    final tieGlyphSize = tester.getSize(
      find.byKey(const ValueKey('slur-tool-glyph-box')),
    );
    final tripletGlyphSize = tester.getSize(
      find.byKey(const ValueKey('triplet-tool-glyph-box')),
    );

    expect(dotGlyphSize, equals(const Size(28, 30)));
    expect(tieGlyphSize, equals(const Size(28, 30)));
    expect(tripletGlyphSize, equals(const Size(28, 30)));
  });

  test('modifier glyph assets share one safe viewBox contract', () {
    for (final asset in const [
      'assets/icons/toolbar/note_quarter_up_with_dot.svg',
      'assets/icons/toolbar/note_quarter_up_with_tie.svg',
      'assets/icons/toolbar/tuplet_bracket_with_3.svg',
    ]) {
      final svg = File(asset).readAsStringSync();
      expect(svg, contains('viewBox="0 0 28 30"'));
    }
  });

  testWidgets('modifier buttons keep a shared baseline alignment', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildModifierAlignmentGolden());
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('modifier-alignment-golden')),
      matchesGoldenFile('goldens/modifier_button_alignment.png'),
    );
  });

  testWidgets('library toast floats without shifting toolbar layout', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    final before = tester.getRect(
      find.byKey(const ValueKey('compose-toolbar')),
    );

    notifier.showLibraryMessage('Loaded "Etude".', isError: false);
    await tester.pump();

    final after = tester.getRect(find.byKey(const ValueKey('compose-toolbar')));
    final toastRect = tester.getRect(
      find.byKey(const ValueKey('library-toast')),
    );
    final floatingRect = tester.getRect(
      find.byKey(const ValueKey('compose-floating-actions')),
    );

    expect(find.byKey(const ValueKey('library-toast')), findsOneWidget);
    expect(find.text('Loaded "Etude".'), findsOneWidget);
    expect(after, equals(before));
    expect(toastRect.overlaps(floatingRect), isFalse);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('save button emphasizes unsaved changes', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    expect(
      _borderColor(
        _buttonDecoration(tester, const ValueKey('save-score-button')),
      ),
      AppColors.surfaceBorder,
    );

    notifier.setTempo(notifier.score.bpm + 1);
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      _borderColor(
        _buttonDecoration(tester, const ValueKey('save-score-button')),
      ),
      AppColors.accentAmber.withAlpha(140),
    );

    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('compose screen stays stable on a compact-width viewport', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 960);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final floatingRect = tester.getRect(
      find.byKey(const ValueKey('compose-floating-actions')),
    );
    final toolbarRect = tester.getRect(
      find.byKey(const ValueKey('compose-toolbar')),
    );

    expect(find.byKey(const ValueKey('compose-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-tempo')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('compose-floating-actions')),
      findsOneWidget,
    );
    expect(floatingRect.bottom, lessThan(toolbarRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating actions stay compact on a wide viewport', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 960);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    final floatingRect = tester.getRect(
      find.byKey(const ValueKey('compose-floating-actions')),
    );
    final stageRect = tester.getRect(
      find.byKey(const ValueKey('compose-score-stage')),
    );
    final saveRect = tester.getRect(
      find.byKey(const ValueKey('save-score-button')),
    );
    final loadRect = tester.getRect(
      find.byKey(const ValueKey('load-score-button')),
    );
    final exportRect = tester.getRect(
      find.byKey(const ValueKey('export-score-button')),
    );

    expect(floatingRect.width, lessThan(stageRect.width * 0.4));
    expect(saveRect.top, equals(loadRect.top));
    expect(loadRect.top, equals(exportRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor switches into inline rhythm test mode', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);
    notifier.score.addNote(
      const Note(midi: 60, duration: NoteDuration.quarter),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Rhythm Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('exit-rhythm-test-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('rhythm-test-primary')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-tempo')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rhythm-test-tempo-increment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rhythm-test-threshold-increment')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('rhythm-test-start')), findsNothing);
    expect(find.byKey(const ValueKey('rhythm-test-reset')), findsNothing);
    expect(find.byKey(const ValueKey('rhythm-test-tap')), findsNothing);
    expect(find.textContaining('The score stays visible.'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(PianoKeyboard), findsNothing);

    final buttonRect = tester.getRect(
      find.byKey(const ValueKey('rhythm-test-primary')),
    );
    expect(buttonRect.width, greaterThan(300));
  });

  testWidgets('rhythm test stays within a compact viewport', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);
    notifier.score.addNote(
      const Note(midi: 60, duration: NoteDuration.quarter),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Rhythm Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final screenHeight = tester.view.physicalSize.height;
    expect(
      tester.getRect(find.byKey(const ValueKey('rhythm-test-primary'))).bottom,
      lessThanOrEqualTo(screenHeight),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('rhythm-test-tempo'))).bottom,
      lessThanOrEqualTo(screenHeight),
    );

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rhythm test parameter buttons support fine adjustment', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    addTearDown(notifier.dispose);
    notifier.score.addNote(
      const Note(midi: 60, duration: NoteDuration.quarter),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Rhythm Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('rhythm-test-tempo-value')),
      findsOneWidget,
    );
    expect(find.text('120'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rhythm-test-tempo-increment')));
    await tester.pump();
    expect(find.text('121'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('rhythm-test-threshold-value')),
      findsOneWidget,
    );
    expect(find.text('0.10 beat'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('rhythm-test-threshold-increment')),
    );
    await tester.pump();
    expect(find.text('0.11 beat'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('duration selector shows rest first and mapped shortcuts', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
      ),
    );

    final restX = tester.getTopLeft(find.byKey(const ValueKey('rest-tool'))).dx;
    final dotX = tester.getTopLeft(find.byKey(const ValueKey('dot-tool'))).dx;

    expect(restX, lessThan(dotX));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);

    notifier.handleRestAction();
    await tester.pump();

    expect(
      _borderColor(_buttonDecoration(tester, const ValueKey('rest-tool'))),
      const Color(0xFF9C27B0),
    );
    expect(find.byKey(const ValueKey('duration-whole')), findsOneWidget);
    expect(find.byKey(const ValueKey('duration-half')), findsOneWidget);
    expect(find.byKey(const ValueKey('duration-quarter')), findsOneWidget);
    expect(find.byKey(const ValueKey('duration-thirtySecond')), findsOneWidget);
  });

  testWidgets('duration selector reflects the selected rest timing state', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    notifier.score.addNote(const Note.rest(duration: NoteDuration.half));
    notifier.selectNote(0);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
      ),
    );

    expect(
      _borderColor(_buttonDecoration(tester, const ValueKey('rest-tool'))),
      const Color(0xFF9C27B0),
    );
    expect(
      _borderColor(_buttonDecoration(tester, const ValueKey('duration-half'))),
      const Color(0xFF2196F3),
    );

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('load sheet shows presets and saved scores in one list', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier(
      scoreLibraryRepository: _WidgetMemoryScoreLibraryRepository(
        ScoreLibrarySnapshot(
          draft: Score(),
          savedScores: [
            SavedScoreEntry(
              id: 'saved-1',
              name: 'Saved Etude',
              updatedAt: DateTime.utc(2026, 3, 22, 11, 0, 0),
              score: Score(
                notes: const [Note(midi: 60, duration: NoteDuration.quarter)],
              ),
            ),
          ],
        ),
      ),
      presetScoreRepository: _WidgetPresetScoreRepository([
        PresetScoreEntry(
          id: 'preset-1',
          name: 'Basic 4/4',
          assetPath: 'assets/presets/basic_4_4.json',
          score: Score(),
        ),
      ]),
    );
    addTearDown(notifier.dispose);
    await notifier.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: ScoreEditorScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('load-score-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Scores'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-score-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('preset-score-preset-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-score-saved-1')), findsOneWidget);
    expect(find.text('Saved Scores'), findsNothing);
    expect(find.byTooltip('Delete Saved Etude'), findsOneWidget);
    expect(find.byTooltip('Delete Basic 4/4'), findsNothing);
  });

  testWidgets('duration selector edits the selected note duration', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    notifier.score.addNote(
      const Note(midi: 60, duration: NoteDuration.quarter),
    );
    notifier.selectNote(0);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('duration-half')));
    await tester.pump();

    expect(notifier.score.notes.single.duration, NoteDuration.half);
    expect(
      _borderColor(_buttonDecoration(tester, const ValueKey('duration-half'))),
      const Color(0xFF2196F3),
    );

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('duration selector highlights a selected valid triplet', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter, tripletGroupId: 3),
      const Note(midi: 62, duration: NoteDuration.quarter, tripletGroupId: 3),
      const Note(midi: 64, duration: NoteDuration.quarter, tripletGroupId: 3),
    ]);
    notifier.selectNote(1);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
      ),
    );

    expect(
      _borderColor(_buttonDecoration(tester, const ValueKey('triplet-tool'))),
      const Color(0xFF00897B),
    );

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('duration selector disables invalid triplet actions', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    notifier.score.notes.addAll([
      const Note(midi: 60, duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.half),
      const Note(midi: 64, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
      ),
    );

    expect(
      _buttonInkWell(tester, const ValueKey('triplet-tool')).onTap,
      isNull,
    );

    expect(
      notifier.score.notes.every((note) => note.tripletGroupId == null),
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
    'duration selector disables duration changes for non-final triplet notes',
    (WidgetTester tester) async {
      final notifier = ScoreNotifier();
      notifier.score.notes.addAll([
        const Note(midi: 60, duration: NoteDuration.eighth, tripletGroupId: 3),
        const Note(midi: 62, duration: NoteDuration.eighth, tripletGroupId: 3),
        const Note(midi: 64, duration: NoteDuration.eighth, tripletGroupId: 3),
      ]);
      notifier.selectNote(1);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notifier,
          child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
        ),
      );

      expect(
        _buttonInkWell(tester, const ValueKey('duration-quarter')).onTap,
        isNull,
      );
      expect(
        _buttonInkWell(tester, const ValueKey('duration-half')).onTap,
        isNull,
      );
    },
  );

  testWidgets('duration selector disables slur on a selected rest', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    notifier.score.notes.addAll([
      const Note.rest(duration: NoteDuration.quarter),
      const Note(midi: 62, duration: NoteDuration.quarter),
    ]);
    notifier.selectNote(0);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
      ),
    );

    expect(_buttonInkWell(tester, const ValueKey('slur-tool')).onTap, isNull);
  });

  testWidgets('duration selector enables delete in end-input mode', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    notifier.score.addNote(
      const Note(midi: 60, duration: NoteDuration.quarter),
    );
    notifier.selectNote(null);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: MaterialApp(home: Scaffold(body: _buildDurationSelector())),
      ),
    );

    expect(
      _buttonInkWell(tester, const ValueKey('delete-tool')).onTap,
      isNotNull,
    );
  });

  testWidgets('piano keyboard shows expanded hints and shift zones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ScoreNotifier(),
        child: const MaterialApp(home: Scaffold(body: PianoKeyboard())),
      ),
    );

    for (final keyLabel in ['a', 'd', 'r', ';', '\'']) {
      expect(find.text(keyLabel), findsOneWidget);
    }
    expect(find.text('q'), findsWidgets);
    expect(find.text(']'), findsWidgets);
    expect(find.text('Key Sig'), findsOneWidget);
    expect(find.text('e'), findsOneWidget);
    expect(find.text('E'), findsNothing);
    expect(find.text('Chromatic'), findsNothing);
    expect(find.text('C#4'), findsNothing);
    expect(find.text('A#3'), findsNothing);
  });

  testWidgets(
    'keyboard mode toggle is compact and key-signature labels show actual pitch',
    (WidgetTester tester) async {
      final notifier = ScoreNotifier();
      notifier.setKeySignature(KeySignature.gMajor);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notifier,
          child: const MaterialApp(home: Scaffold(body: PianoKeyboard())),
        ),
      );

      final toggleRect = tester.getRect(
        find.byKey(const ValueKey('keyboard-mode-toggle')),
      );
      expect(toggleRect.height, lessThanOrEqualTo(34));
      expect(toggleRect.width, lessThanOrEqualTo(68));

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('piano-white-65')),
          matching: find.text('F#4'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('piano keyboard toggle and arrow controls update shared state', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    notifier.score.addNote(
      const Note(midi: 60, duration: NoteDuration.quarter),
    );
    notifier.selectKeySig();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: Scaffold(body: PianoKeyboard())),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('keyboard-mode-toggle')));
    await tester.pump();
    expect(notifier.keyboardInputMode.name, 'chromatic');
    expect(find.text('Chromatic'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('piano-white-65')),
        matching: find.text('F4'),
      ),
      findsOneWidget,
    );

    _buttonInkWell(tester, const ValueKey('keyboard-nav-right')).onTap?.call();
    await tester.pump();
    expect(notifier.selectionKind, SelectionKind.timeSig);

    _buttonInkWell(tester, const ValueKey('keyboard-nav-down')).onTap?.call();
    await tester.pump();
    expect(notifier.score.beatsPerMeasure, 3);
  });

  testWidgets('piano taps use real keys instead of q shift hints', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: Scaffold(body: PianoKeyboard())),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('piano-white-45')));
    await tester.pump();

    expect(notifier.keyboardOctaveShift, 0);
    expect(notifier.score.notes, hasLength(1));
    expect(notifier.score.notes.single.midi, 45);

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('key-signature mode disables direct taps on black keys', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: Scaffold(body: PianoKeyboard())),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('piano-black-61')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(notifier.score.notes, isEmpty);
  });

  testWidgets('chromatic mode allows direct taps on black keys', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
    notifier.toggleKeyboardInputMode();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: Scaffold(body: PianoKeyboard())),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('piano-black-61')));
    await tester.pump();

    expect(notifier.score.notes, hasLength(1));
    expect(notifier.score.notes.single.midi, 61);

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('keyboard shortcuts insert rests and notes', (
    WidgetTester tester,
  ) async {
    final context = await _openBlankEditor(tester);
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.backquote);
    await tester.pump();
    expect(notifier.restMode, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1);
    await tester.pump();

    expect(notifier.restMode, isFalse);
    expect(notifier.score.notes, hasLength(1));
    expect(notifier.score.notes.single.isRest, isTrue);
    expect(notifier.score.notes.single.duration.name, 'whole');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await tester.pump();

    expect(notifier.score.notes, hasLength(2));
    expect(notifier.score.notes.last.isRest, isFalse);
    expect(notifier.score.notes.last.midi, 60);

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
    'keyboard shortcuts support thirty-second notes, slurs, and end delete',
    (WidgetTester tester) async {
      final context = await _openBlankEditor(tester);
      final notifier = Provider.of<ScoreNotifier>(context, listen: false);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit6);
      await tester.pump();
      expect(notifier.currentDuration, NoteDuration.thirtySecond);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.digit8);
      await tester.pump();
      expect(notifier.slurMode, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.pump();
      expect(notifier.score.notes.single.duration, NoteDuration.thirtySecond);
      expect(notifier.score.notes.single.slurToNext, isTrue);
      expect(notifier.slurMode, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(notifier.score.notes, isEmpty);

      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  testWidgets('keyboard shortcuts support octave shift and chromatic toggle', (
    WidgetTester tester,
  ) async {
    final context = await _openBlankEditor(tester);
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pump();
    expect(notifier.keyboardOctaveShift, -1);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(notifier.score.notes.single.midi, 48);

    notifier.score.notes.clear();
    notifier.moveCursor(0);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.pump();
    expect(notifier.keyboardOctaveShift, 0);

    notifier.setKeySignature(KeySignature.gMajor);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(notifier.score.notes.single.midi, 66);

    notifier.score.notes.clear();
    notifier.moveCursor(0);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(notifier.keyboardInputMode.name, 'chromatic');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(notifier.score.notes.single.midi, 65);

    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets(
    'keyboard shortcuts still resolve a, s, and apostrophe after exiting rhythm test',
    (WidgetTester tester) async {
      final notifier = ScoreNotifier();
      addTearDown(notifier.dispose);
      notifier.score.addNote(
        const Note(midi: 60, duration: NoteDuration.quarter),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: notifier,
          child: const MaterialApp(home: ScoreEditorScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Rhythm Test'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byTooltip('Exit Rhythm Test'));
      await tester.pump();

      notifier.selectNote(null);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS, character: 's');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.quote, character: '\'');
      await tester.pump();

      expect(notifier.score.notes.map((note) => note.midi).toList(), [
        60,
        57,
        59,
        74,
      ]);

      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}

class _WidgetMemoryScoreLibraryRepository implements ScoreLibraryRepository {
  _WidgetMemoryScoreLibraryRepository([this.snapshot]);

  ScoreLibrarySnapshot? snapshot;

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot nextSnapshot) async {
    snapshot = nextSnapshot;
  }
}

class _WidgetPresetScoreRepository implements PresetScoreRepository {
  const _WidgetPresetScoreRepository(this._presets);

  final List<PresetScoreEntry> _presets;

  @override
  Future<List<PresetScoreEntry>> loadPresets() async => _presets;
}
