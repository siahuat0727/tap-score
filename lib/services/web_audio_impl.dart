// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';

@JS('initWebAudio')
external void _initWebAudio();

@JS('playWebNote')
external void _playWebNote(int midi, int velocity);

@JS('stopWebNote')
external void _stopWebNote(int midi);

Future<void> initWebAudio() async {
  _initWebAudio();
}

void playWebNote(int midi, int velocity) {
  _playWebNote(midi, velocity);
}

void stopWebNote(int midi) {
  _stopWebNote(midi);
}
