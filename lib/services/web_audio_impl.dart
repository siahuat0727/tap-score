// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:async';

@JS('initWebAudio')
external JSAny? _initWebAudio();

@JS('isWebAudioReady')
external JSBoolean _isWebAudioReady();

@JS('getWebAudioInitError')
external JSString _getWebAudioInitError();

@JS('playWebNote')
external JSNumber _playWebNote(int midi, int velocity);

@JS('stopWebNote')
external void _stopWebNote(int handleId);

Future<bool> initWebAudio({
  Duration timeout = const Duration(seconds: 10),
}) async {
  _initWebAudio();

  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (_isWebAudioReady().toDart) {
      return true;
    }

    final error = _getWebAudioInitError().toDart;
    if (error.isNotEmpty) {
      throw StateError(error);
    }

    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  throw TimeoutException('Timed out waiting for Web Audio initialization.');
}

int playWebNote(int midi, int velocity) {
  return _playWebNote(midi, velocity).toDartInt;
}

void stopWebNote(int handleId) {
  _stopWebNote(handleId);
}
