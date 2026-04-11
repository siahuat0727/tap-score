import 'package:web/web.dart' as web;

void notifyAppShellReady() {
  web.window.dispatchEvent(web.CustomEvent('tap-score:flutter-first-frame'));
}
