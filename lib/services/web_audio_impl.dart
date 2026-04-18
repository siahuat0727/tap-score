// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'dart:async';

@JS('initWebAudio')
external JSPromise<JSBoolean> _initWebAudio();

@JS('getWebAudioInitError')
external JSString _getWebAudioInitError();

@JS('playWebNote')
external JSNumber _playWebNote(int midi, int velocity);

@JS('stopWebNote')
external void _stopWebNote(int handleId);

@JS('preloadWebNotes')
external JSPromise<JSAny?> _preloadWebNotes(JSArray<JSNumber> midis);

Future<T> _awaitWithTimeout<T>(
  Future<T> future, {
  required Duration timeout,
  required String timeoutMessage,
}) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException {
    throw TimeoutException(timeoutMessage);
  }
}

Future<bool> initWebAudio({
  Duration timeout = const Duration(seconds: 12),
}) async {
  final initialized = await _awaitWithTimeout(
    _initWebAudio().toDart.then((result) => result.toDart),
    timeout: timeout,
    timeoutMessage: 'Timed out waiting for Web Audio initialization.',
  );
  if (initialized) {
    return true;
  }

  final error = _getWebAudioInitError().toDart;
  throw StateError(
    error.isNotEmpty ? error : 'Piano audio failed to initialize.',
  );
}

int playWebNote(int midi, int velocity) {
  return _playWebNote(midi, velocity).toDartInt;
}

void stopWebNote(int handleId) {
  _stopWebNote(handleId);
}

Future<void> preloadWebNotes(
  List<int> midis, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final jsMidis = midis.map((midi) => midi.toJS).toList(growable: false).toJS;
  await _awaitWithTimeout(
    _preloadWebNotes(jsMidis).toDart,
    timeout: timeout,
    timeoutMessage: 'Timed out waiting for rhythm test audio preload.',
  );
}
