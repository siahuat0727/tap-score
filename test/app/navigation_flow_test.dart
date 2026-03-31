import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_score/main.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';
import 'package:tap_score/screens/score_editor_screen.dart';
import 'package:tap_score/services/preset_score_repository.dart';
import 'package:tap_score/services/score_library_repository.dart';
import 'package:tap_score/state/score_notifier.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers/fake_webview_platform.dart';

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  testWidgets('blank editor flow keeps compose context and home access', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    expect(find.text('Create New Score'), findsOneWidget);
    expect(find.text('Practice from Preset'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('launch-new-blank-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ScoreEditorScreen), findsOneWidget);
    expect(find.text('Compose'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-score-button')), findsOneWidget);

    final context = tester.element(find.byType(ScoreEditorScreen));
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);
    expect(notifier.activePresetId, isNull);
    expect(notifier.score.notes, isEmpty);
  });

  testWidgets('practice from preset goes to practice and can open editor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(presets: _presets));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('launch-preset-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Choose a preset to start the rhythm test'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('preset-option-preset-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ScoreEditorScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Choose Another Preset'), findsOneWidget);
    expect(find.text('Open in Editor'), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-primary')), findsOneWidget);

    await tester.tap(find.text('Open in Editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ScoreEditorScreen), findsOneWidget);
    expect(find.text('Compose'), findsOneWidget);
    expect(find.text('Triplet Study'), findsWidgets);

    final context = tester.element(find.byType(ScoreEditorScreen));
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);
    expect(notifier.activePresetId, 'preset-1');
    expect(notifier.currentScoreLabel, 'Triplet Study');
  });

  testWidgets('practice screen can choose another preset directly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(presets: _presets));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('launch-preset-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('preset-option-preset-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Choose Another Preset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('launch-preset-modal')), findsOneWidget);
    expect(
      find.text('Choose a preset to start the rhythm test'),
      findsOneWidget,
    );
  });

  testWidgets('editor rhythm test provides a back-to-editor action', (
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

    expect(find.text('Back to Editor'), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-primary')), findsOneWidget);

    await tester.tap(find.text('Back to Editor'));
    await tester.pump();

    expect(find.byKey(const ValueKey('compose-toolbar')), findsOneWidget);
    expect(find.byType(ScoreEditorScreen), findsOneWidget);
  });
}

final _presets = [
  PresetScoreEntry(
    id: 'preset-1',
    name: 'Triplet Study',
    assetPath: 'assets/presets/triplet_study.json',
    score: Score(
      notes: const [Note(midi: 67, duration: NoteDuration.quarter)],
      bpm: 96,
    ),
  ),
];

TapScoreApp _buildTestApp({
  List<PresetScoreEntry> presets = const [],
  ScoreLibrarySnapshot? snapshot,
}) {
  return TapScoreApp(
    presetScoreRepository: _AppPresetScoreRepository(presets),
    scoreLibraryRepository: _AppMemoryScoreLibraryRepository(snapshot),
  );
}

class _AppMemoryScoreLibraryRepository implements ScoreLibraryRepository {
  _AppMemoryScoreLibraryRepository([this.snapshot]);

  ScoreLibrarySnapshot? snapshot;

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot nextSnapshot) async {
    snapshot = nextSnapshot;
  }
}

class _AppPresetScoreRepository implements PresetScoreRepository {
  const _AppPresetScoreRepository(this.presets);

  final List<PresetScoreEntry> presets;

  @override
  Future<List<PresetScoreEntry>> loadPresets() async => presets;
}
