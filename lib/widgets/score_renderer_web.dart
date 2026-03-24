import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import 'score_renderer_stub.dart';

/// Web implementation using an iframe inside [HtmlElementView].
Widget buildScoreRenderer({
  required bool interactive,
  required OnScoreMessage onMessage,
  required OnRendererReady onReady,
}) {
  return _WebScoreRenderer(
    interactive: interactive,
    onMessage: onMessage,
    onReady: onReady,
  );
}

class _WebScoreRenderer extends StatefulWidget {
  final bool interactive;
  final OnScoreMessage onMessage;
  final OnRendererReady onReady;

  const _WebScoreRenderer({
    required this.interactive,
    required this.onMessage,
    required this.onReady,
  });

  @override
  State<_WebScoreRenderer> createState() => _WebScoreRendererState();
}

class _WebScoreRendererState extends State<_WebScoreRenderer> {
  static int _nextId = 0;
  late final String _viewType;
  late final JSFunction _jsMessageHandler;
  web.HTMLIFrameElement? _iframe;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'score-renderer-${_nextId++}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (
      int viewId, {
      Object? params,
    }) {
      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = 'assets/assets/html/score_renderer.html';
      iframe.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%'
        ..pointerEvents = widget.interactive ? 'auto' : 'none';
      _iframe = iframe;
      return iframe;
    });

    // Store the JS function reference so we can remove it later.
    _jsMessageHandler = _onWindowMessage.toJS;
    web.window.addEventListener('message', _jsMessageHandler);
  }

  void _onWindowMessage(web.Event event) {
    final msgEvent = event as web.MessageEvent;
    try {
      final raw = msgEvent.data;
      if (raw == null) return;
      if (!raw.typeofEquals('string')) return;
      final jsonStr = (raw as JSString).toDart;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (data['type'] == 'ready' && !_ready) {
        _ready = true;
        widget.onReady(_sendRender);
      }
      widget.onMessage(data);
    } catch (_) {
      // Ignore messages from other sources.
    }
  }

  void _sendRender(Map<String, dynamic> payload) {
    if (_iframe == null) return;
    final jsonStr = jsonEncode(payload);
    _iframe!.contentWindow?.postMessage(jsonStr.toJS, '*'.toJS);
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _jsMessageHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
