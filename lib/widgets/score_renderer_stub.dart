import 'package:flutter/widgets.dart';

/// Callback when a message arrives from JS.
typedef OnScoreMessage = void Function(Map<String, dynamic> message);

/// Callback that delivers the [sendRender] function once the platform view is
/// ready. The parent can then call [sendRender] whenever the score state
/// changes.
typedef OnRendererReady =
    void Function(void Function(Map<String, dynamic> payload) sendRender);

/// Creates the platform-specific score rendering widget.
///
/// Implementations must:
/// 1. Load `assets/html/score_renderer.html`.
/// 2. Call [onMessage] when receiving a JS message.
/// 3. Call [onReady] with a `sendRender` function once the page is loaded and
///    ready to accept render commands.
Widget buildScoreRenderer({
  required OnScoreMessage onMessage,
  required OnRendererReady onReady,
}) {
  throw UnsupportedError('Platform not supported');
}
