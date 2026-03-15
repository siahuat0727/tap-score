import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const TapScoreApp());
    await tester.pumpAndSettle();

    // Verify the app title is shown.
    expect(find.text('Tap Score'), findsOneWidget);
  });
}
