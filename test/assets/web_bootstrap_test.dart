import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web bootstrap explains the browser-to-Flutter handoff', () {
    final html = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(html, contains('id="tap-score-bootstrap"'));
    expect(html, contains('Browser and Flutter bootstrap'));
    expect(html, contains('App shell ready'));
    expect(html, contains('Workspace prepares inside the app'));
    expect(html, contains('tap-score:flutter-first-frame'));
    expect(html, contains('Tap Score could not start'));

    expect(bootstrap, contains('onEntrypointLoaded'));
    expect(bootstrap, contains("setStage('engine')"));
    expect(bootstrap, contains("setStage('launch')"));
    expect(
      bootstrap,
      contains(
        'Tap Score could not start in this browser session. Reload to try again.',
      ),
    );
  });
}
