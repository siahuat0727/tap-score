import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/key_signature.dart';

void main() {
  group('alteredPitches', () {
    test('C major has no altered pitches', () {
      expect(KeySignature.cMajor.alteredPitches, isEmpty);
    });

    test('G major has F# (pitch class 6)', () {
      expect(KeySignature.gMajor.alteredPitches, {6});
    });

    test('D major has F# and C# (pitch classes 6, 1)', () {
      expect(KeySignature.dMajor.alteredPitches, {6, 1});
    });

    test('A major has F#, C#, G# (pitch classes 6, 1, 8)', () {
      expect(KeySignature.aMajor.alteredPitches, {6, 1, 8});
    });

    test('F major has Bb (pitch class 10)', () {
      expect(KeySignature.fMajor.alteredPitches, {10});
    });

    test('Bb major has Bb and Eb (pitch classes 10, 3)', () {
      expect(KeySignature.bbMajor.alteredPitches, {10, 3});
    });

    test('Eb major has Bb, Eb, Ab (pitch classes 10, 3, 8)', () {
      expect(KeySignature.ebMajor.alteredPitches, {10, 3, 8});
    });
  });

  group('accidentalOffset', () {
    test('C major returns 0', () {
      expect(KeySignature.cMajor.accidentalOffset, 0);
    });

    test('sharp keys return +1', () {
      for (final key in [
        KeySignature.gMajor,
        KeySignature.dMajor,
        KeySignature.aMajor,
        KeySignature.eMajor,
        KeySignature.bMajor,
        KeySignature.fSharpMajor,
      ]) {
        expect(key.accidentalOffset, 1, reason: '${key.displayName}');
      }
    });

    test('flat keys return -1', () {
      for (final key in [
        KeySignature.fMajor,
        KeySignature.bbMajor,
        KeySignature.ebMajor,
        KeySignature.abMajor,
        KeySignature.dbMajor,
        KeySignature.gbMajor,
      ]) {
        expect(key.accidentalOffset, -1, reason: '${key.displayName}');
      }
    });
  });

  group('applyToMidi', () {
    test('C major does not alter any MIDI value', () {
      // F4 = MIDI 65, should stay 65
      expect(KeySignature.cMajor.applyToMidi(65), 65);
    });

    test('G major raises F to F# (MIDI 65 → 66)', () {
      expect(KeySignature.gMajor.applyToMidi(65), 66);
    });

    test('G major does not alter C (MIDI 60)', () {
      expect(KeySignature.gMajor.applyToMidi(60), 60);
    });

    test('D major raises F to F# and C to C#', () {
      expect(KeySignature.dMajor.applyToMidi(65), 66); // F → F#
      expect(KeySignature.dMajor.applyToMidi(60), 61); // C → C#
    });

    test('F major lowers B to Bb (MIDI 71 → 70)', () {
      expect(KeySignature.fMajor.applyToMidi(71), 70);
    });

    test('F major does not alter E (MIDI 64)', () {
      expect(KeySignature.fMajor.applyToMidi(64), 64);
    });

    test('Bb major lowers B and E (MIDI 71 → 70, 64 → 63)', () {
      expect(KeySignature.bbMajor.applyToMidi(71), 70); // B → Bb
      expect(KeySignature.bbMajor.applyToMidi(64), 63); // E → Eb
    });

    test('applyToMidi works across octaves', () {
      // F in different octaves should all be raised in G major
      expect(KeySignature.gMajor.applyToMidi(41), 42); // F2
      expect(KeySignature.gMajor.applyToMidi(53), 54); // F3
      expect(KeySignature.gMajor.applyToMidi(65), 66); // F4
      expect(KeySignature.gMajor.applyToMidi(77), 78); // F5
    });
  });

  group('circle-of-fifths navigation', () {
    test('nextSharp from C major goes to G major', () {
      expect(KeySignature.cMajor.nextSharp, KeySignature.gMajor);
    });

    test('nextFlat from C major goes to F major', () {
      expect(KeySignature.cMajor.nextFlat, KeySignature.fMajor);
    });

    test('nextSharp from G major goes to D major', () {
      expect(KeySignature.gMajor.nextSharp, KeySignature.dMajor);
    });

    test('nextFlat from F major goes to Bb major', () {
      expect(KeySignature.fMajor.nextFlat, KeySignature.bbMajor);
    });

    test('nextSharp at F# major stays at F# major (boundary)', () {
      expect(KeySignature.fSharpMajor.nextSharp, KeySignature.fSharpMajor);
    });

    test('nextFlat at Gb major stays at Gb major (boundary)', () {
      expect(KeySignature.gbMajor.nextFlat, KeySignature.gbMajor);
    });

    test('full circle: C → sharps → F# major in 6 steps', () {
      var key = KeySignature.cMajor;
      final expected = [
        KeySignature.gMajor,
        KeySignature.dMajor,
        KeySignature.aMajor,
        KeySignature.eMajor,
        KeySignature.bMajor,
        KeySignature.fSharpMajor,
      ];
      for (final exp in expected) {
        key = key.nextSharp;
        expect(key, exp);
      }
    });

    test('full circle: C → flats → Gb major in 6 steps', () {
      var key = KeySignature.cMajor;
      final expected = [
        KeySignature.fMajor,
        KeySignature.bbMajor,
        KeySignature.ebMajor,
        KeySignature.abMajor,
        KeySignature.dbMajor,
        KeySignature.gbMajor,
      ];
      for (final exp in expected) {
        key = key.nextFlat;
        expect(key, exp);
      }
    });
  });

  group('diatonicStep', () {
    test('C major: C4 up → D4 (60 → 62)', () {
      expect(KeySignature.cMajor.diatonicStep(60, 1), 62);
    });

    test('C major: E4 up → F4 (64 → 65, half step)', () {
      expect(KeySignature.cMajor.diatonicStep(64, 1), 65);
    });

    test('C major: B4 up → C5 (71 → 72, half step)', () {
      expect(KeySignature.cMajor.diatonicStep(71, 1), 72);
    });

    test('C major: D4 down → C4 (62 → 60)', () {
      expect(KeySignature.cMajor.diatonicStep(62, -1), 60);
    });

    test('G major: F#4 up → G4 (66 → 67)', () {
      expect(KeySignature.gMajor.diatonicStep(66, 1), 67);
    });

    test('G major: E4 up → F#4 (64 → 66)', () {
      expect(KeySignature.gMajor.diatonicStep(64, 1), 66);
    });

    test('G major: G4 down → F#4 (67 → 66)', () {
      expect(KeySignature.gMajor.diatonicStep(67, -1), 66);
    });

    test('F major: A4 up → Bb4 (69 → 70)', () {
      expect(KeySignature.fMajor.diatonicStep(69, 1), 70);
    });

    test('F major: Bb4 up → C5 (70 → 72)', () {
      expect(KeySignature.fMajor.diatonicStep(70, 1), 72);
    });

    test('F major: C5 down → Bb4 (72 → 70)', () {
      expect(KeySignature.fMajor.diatonicStep(72, -1), 70);
    });

    test('scalePitchClasses for C major', () {
      expect(KeySignature.cMajor.scalePitchClasses, {0, 2, 4, 5, 7, 9, 11});
    });

    test('scalePitchClasses for G major', () {
      // G A B C D E F# → 7 9 11 0 2 4 6
      expect(KeySignature.gMajor.scalePitchClasses, {7, 9, 11, 0, 2, 4, 6});
    });

    test('scalePitchClasses for F major', () {
      // F G A Bb C D E → 5 7 9 10 0 2 4
      expect(KeySignature.fMajor.scalePitchClasses, {5, 7, 9, 10, 0, 2, 4});
    });
  });
}
