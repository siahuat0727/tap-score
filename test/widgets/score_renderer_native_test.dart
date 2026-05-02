import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/widgets/score_renderer_native.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers/fake_webview_platform.dart';

void main() {
  setUpAll(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
  });

  setUp(() {
    FakeWebViewPlatform.reset();
  });

  testWidgets('native renderer preserves JSON string escapes in JS bridge', (
    WidgetTester tester,
  ) async {
    late void Function(Map<String, dynamic> payload) sendRender;

    await tester.pumpWidget(
      MaterialApp(
        home: buildScoreRenderer(
          interactive: false,
          pointerInputEnabled: false,
          onMessage: (_) {},
          onReady: (renderer) {
            sendRender = renderer;
          },
        ),
      ),
    );
    await tester.pump();

    final payload = {
      'type': 'render',
      'title': 'A "quoted"\nscore at C:\\temp\\score',
      'notes': const <Map<String, dynamic>>[],
    };

    sendRender(payload);

    expect(FakeWebViewPlatform.runJavaScriptCalls, isNotEmpty);
    expect(
      FakeWebViewPlatform.runJavaScriptCalls.last,
      'window.renderFromDart(${jsonEncode(jsonEncode(payload))})',
    );
  });
}
