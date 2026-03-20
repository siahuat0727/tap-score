import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('score renderer forwards editing shortcuts from the iframe', () {
    final html = File('assets/html/score_renderer.html').readAsStringSync();

    expect(html, contains('const forwardedCodes = ['));
    expect(html, contains("'KeyD'"));
    expect(html, contains("'KeyL'"));
    expect(html, contains("'Backquote'"));
    expect(html, contains("'Digit1'"));
    expect(html, contains("'Digit6'"));
    expect(html, contains("'Digit7'"));
    expect(html, contains("'Digit8'"));
    expect(html, contains("'Digit9'"));
    expect(html, contains("code: e.code"));
  });

  test(
    'score renderer includes thirty-second durations and slur rendering',
    () {
      final html = File('assets/html/score_renderer.html').readAsStringSync();

      expect(html, contains("dur: '32'"));
      expect(html, contains('source.slurToNext'));
      expect(html, contains('new Curve('));
    },
  );
}
