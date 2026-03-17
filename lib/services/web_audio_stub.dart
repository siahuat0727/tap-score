// Stub for web audio functions to compile safely on native platforms.

Future<bool> initWebAudio({
  Duration timeout = const Duration(seconds: 10),
}) async {
  return false;
}

void playWebNote(int midi, int velocity) {}
void stopWebNote(int midi) {}
