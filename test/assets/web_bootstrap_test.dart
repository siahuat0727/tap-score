import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web bootstrap explains the browser-to-Flutter handoff', () {
    final html = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    final headers = File('web/_headers').readAsStringSync();

    expect(html, contains('id="tap-score-bootstrap"'));
    expect(html, contains('Browser and Flutter bootstrap'));
    expect(html, contains('App shell ready'));
    expect(html, contains('Workspace prepares inside the app'));
    expect(html, contains('tap-score:flutter-first-frame'));
    expect(html, contains('Tap Score could not start'));
    expect(
      html,
      contains('flutter_bootstrap.js?v=__TAP_SCORE_DEPLOY_ID__'),
    );

    expect(bootstrap, contains('onEntrypointLoaded'));
    expect(bootstrap, contains('__TAP_SCORE_DEPLOY_ID__'));
    expect(bootstrap, contains("setStage('engine')"));
    expect(bootstrap, contains("setStage('launch')"));
    expect(bootstrap, contains('mainJsPath'));
    expect(
      bootstrap,
      contains(
        'Tap Score could not start in this browser session. Reload to try again.',
      ),
    );

    expect(headers, contains('/flutter_bootstrap.js'));
    expect(headers, contains('/main.dart.js'));
    expect(headers, contains('/flutter.js'));
    expect(headers, contains('/flutter_service_worker.js'));
    expect(headers, contains('/manifest.json'));
    expect(headers, contains('/version.json'));
    expect(headers, contains('Cache-Control: public, max-age=0, must-revalidate'));
    expect(
      headers,
      isNot(contains('Cache-Control: public, max-age=31536000, immutable\n\n/*.mjs')),
    );
  });
}
