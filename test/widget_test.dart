import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_score/main.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/key_signature.dart';
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
    expect(find.text('Mode: Key Signature'), findsOneWidget);
    expect(find.text('e'), findsOneWidget);
    expect(find.text('E'), findsNothing);
    expect(find.text('Key Sig'), findsNothing);
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
    expect(find.text('Mode: Chromatic'), findsOneWidget);
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

  testWidgets('keyboard shortcuts support octave shift and chromatic toggle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TapScoreApp());
    await tester.pump();

    final context = tester.element(find.byType(ScoreEditorScreen));
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
}
