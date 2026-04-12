import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/services/audio_service.dart';

void main() {
  test('rhythm test note preload is safe in test mode', () async {
    final audioService = AudioService(testMode: true);

    await audioService.preloadRhythmTestNotes([60, 62, 60]);

    expect(audioService.isInitialized, isTrue);
  });
}
