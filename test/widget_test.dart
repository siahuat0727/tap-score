import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_score/main.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/screens/score_editor_screen.dart';
import 'package:tap_score/state/score_notifier.dart';
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

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const TapScoreApp());
    await tester.pump();

    // Verify the app title is shown.
    expect(find.text('Tap Score'), findsOneWidget);
  });

  testWidgets('editor switches into inline rhythm test mode', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
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

    expect(find.text('Rhythm Test'), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-reset')), findsOneWidget);
    expect(find.byKey(const ValueKey('rhythm-test-tap')), findsOneWidget);
    expect(find.textContaining('The score stays visible.'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(PianoKeyboard), findsNothing);
  });

  testWidgets('rhythm test stays within a compact viewport', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();
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
    for (final finder in [
      find.byKey(const ValueKey('rhythm-test-start')),
      find.byKey(const ValueKey('rhythm-test-reset')),
      find.byKey(const ValueKey('rhythm-test-tap')),
    ]) {
      expect(tester.getRect(finder).bottom, lessThanOrEqualTo(screenHeight));
    }

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duration selector shows rest first and mapped shortcuts', (
    WidgetTester tester,
  ) async {
    final notifier = ScoreNotifier();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: notifier,
        child: const MaterialApp(home: Scaffold(body: DurationSelector())),
      ),
    );

    final restX = tester.getTopLeft(find.text('Rest')).dx;
    final dotX = tester.getTopLeft(find.text('Dot')).dx;

    expect(restX, lessThan(dotX));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);

    notifier.handleRestAction();
    await tester.pump();

    expect(find.text('𝄻'), findsOneWidget);
    expect(find.text('𝄼'), findsOneWidget);
    expect(find.text('𝄽'), findsOneWidget);
    expect(find.text('𝅀'), findsOneWidget);
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
        child: const MaterialApp(home: Scaffold(body: DurationSelector())),
      ),
    );

    expect(find.text('𝄼'), findsOneWidget);
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
        child: const MaterialApp(home: Scaffold(body: DurationSelector())),
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
        child: const MaterialApp(home: Scaffold(body: DurationSelector())),
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
        child: const MaterialApp(home: Scaffold(body: DurationSelector())),
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
        child: const MaterialApp(home: Scaffold(body: DurationSelector())),
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
        child: const MaterialApp(home: Scaffold(body: DurationSelector())),
      ),
    );

    expect(
      _buttonInkWell(tester, const ValueKey('delete-tool')).onTap,
      isNotNull,
    );
  });

  testWidgets('piano keyboard shows mapped key hints on C4-B4', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ScoreNotifier(),
        child: const MaterialApp(home: Scaffold(body: PianoKeyboard())),
      ),
    );

    for (final keyLabel in ['d', 'f', 'g', 'h', 'j', 'k', 'l']) {
      expect(find.text(keyLabel), findsOneWidget);
    }
  });

  testWidgets('keyboard shortcuts insert rests and notes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TapScoreApp());
    await tester.pump();

    final context = tester.element(find.byType(ScoreEditorScreen));
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
      await tester.pumpWidget(const TapScoreApp());
      await tester.pump();

      final context = tester.element(find.byType(ScoreEditorScreen));
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
}
