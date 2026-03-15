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
}
