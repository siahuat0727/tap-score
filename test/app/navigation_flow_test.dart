import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_score/main.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/models/score.dart';
import 'package:tap_score/models/score_library.dart';
import 'package:tap_score/screens/workspace_screen.dart';
import 'package:tap_score/services/preset_score_repository.dart';
import 'package:tap_score/services/score_library_repository.dart';
import 'package:tap_score/state/score_notifier.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers/fake_webview_platform.dart';

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  testWidgets('create new score opens the unified workspace in compose', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('launch-new-blank-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-top-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-mode-compose')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-home-button')), findsOneWidget);

    final context = tester.element(find.byType(WorkspaceScreen));
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);
    expect(notifier.activePresetId, isNull);
    expect(notifier.score.notes, isEmpty);
  });

  testWidgets('practice from preset opens the same workspace in rhythm test', (
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

    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-top-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-primary')), findsOneWidget);
    expect(find.text('Open in Editor'), findsNothing);
    expect(find.text('Choose Another Preset'), findsNothing);

    final context = tester.element(find.byType(WorkspaceScreen));
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);
    expect(notifier.activePresetId, 'preset-1');
    expect(notifier.currentScoreLabel, 'Triplet Study');
  });

  testWidgets('mode switch works both directions and keeps the same preset', (
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

    await tester.tap(find.byKey(const ValueKey('workspace-mode-compose')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const ValueKey('compose-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-primary')), findsNothing);

    final context = tester.element(find.byType(WorkspaceScreen));
    final notifier = Provider.of<ScoreNotifier>(context, listen: false);
    expect(notifier.activePresetId, 'preset-1');
    expect(notifier.currentScoreLabel, 'Triplet Study');

    await tester.tap(find.byKey(const ValueKey('workspace-mode-rhythm-test')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const ValueKey('rhythm-test-primary')), findsOneWidget);
    expect(find.byKey(const ValueKey('compose-toolbar')), findsNothing);
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
