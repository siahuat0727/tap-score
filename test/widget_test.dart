import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_score/main.dart';
import 'package:tap_score/screens/score_editor_screen.dart';
import 'package:tap_score/state/score_notifier.dart';
import 'package:tap_score/widgets/duration_selector.dart';
import 'package:tap_score/widgets/piano_keyboard.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'helpers/fake_webview_platform.dart';

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
    expect(find.text('9'), findsOneWidget);

    notifier.handleRestAction();
    await tester.pump();

    expect(find.text('𝄻'), findsOneWidget);
    expect(find.text('𝄼'), findsOneWidget);
    expect(find.text('𝄽'), findsOneWidget);
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
}
