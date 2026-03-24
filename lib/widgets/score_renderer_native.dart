import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'score_renderer_stub.dart';

/// Native implementation using `webview_flutter`.
Widget buildScoreRenderer({
  required bool interactive,
  required OnScoreMessage onMessage,
  required OnRendererReady onReady,
}) {
  return _NativeScoreRenderer(
    interactive: interactive,
    onMessage: onMessage,
    onReady: onReady,
  );
}

class _NativeScoreRenderer extends StatefulWidget {
  final bool interactive;
  final OnScoreMessage onMessage;
  final OnRendererReady onReady;

  const _NativeScoreRenderer({
    required this.interactive,
    required this.onMessage,
    required this.onReady,
  });

  @override
  State<_NativeScoreRenderer> createState() => _NativeScoreRendererState();
}

class _NativeScoreRendererState extends State<_NativeScoreRenderer> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('TapScore', onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {}))
      ..loadFlutterAsset('assets/html/score_renderer.html');
  }

  void _onJsMessage(JavaScriptMessage msg) {
    try {
      final data = jsonDecode(msg.message) as Map<String, dynamic>;
      if (data['type'] == 'ready' && !_ready) {
        _ready = true;
        widget.onReady(_sendRender);
      }
      widget.onMessage(data);
    } catch (e) {
      debugPrint('NativeScoreRenderer: $e');
    }
  }

  void _sendRender(Map<String, dynamic> payload) {
    final jsonStr = jsonEncode(payload).replaceAll("'", "\\'");
    _controller.runJavaScript("window.renderFromDart('$jsonStr')");
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !widget.interactive,
          child: WebViewWidget(controller: _controller),
        ),
        if (!_ready) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
