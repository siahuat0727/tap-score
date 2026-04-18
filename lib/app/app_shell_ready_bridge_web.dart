import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

void notifyAppShellReady() {
  web.window.dispatchEvent(web.CustomEvent('tap-score:flutter-first-frame'));
}

void publishWorkspaceStartupState({
  required String title,
  required String detail,
  required String workspaceLabel,
  required String rendererLabel,
  required String workspaceState,
  required String rendererState,
  String? audioLabel,
  String? audioState,
  bool dismissBootstrap = false,
  bool yieldToFlutter = false,
}) {
  final payload = jsonEncode(<String, Object?>{
    'title': title,
    'detail': detail,
    'workspaceLabel': workspaceLabel,
    'rendererLabel': rendererLabel,
    'workspaceState': workspaceState,
    'rendererState': rendererState,
    'audioLabel': audioLabel,
    'audioState': audioState,
    'dismissBootstrap': dismissBootstrap,
    'yieldToFlutter': yieldToFlutter,
  });
  web.window.dispatchEvent(
    web.CustomEvent(
      'tap-score:workspace-startup',
      web.CustomEventInit(detail: payload.toJS),
    ),
  );
}
