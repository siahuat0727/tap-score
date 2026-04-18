// Stub for web audio functions to compile safely on native platforms.

Future<bool> initWebAudio({
  Duration timeout = const Duration(seconds: 12),
}) async {
  return false;
}

int playWebNote(int midi, int velocity) => -1;
void stopWebNote(int handleId) {}

Future<void> preloadWebNotes(
  List<int> midis, {
  Duration timeout = const Duration(seconds: 12),
}) async {}
