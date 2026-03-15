import 'enums.dart';

/// Represents a single musical note or rest.
class Note {
  /// MIDI note number (e.g. 60 = C4). Ignored if [isRest] is true.
  final int midi;

  /// Duration of this note.
  final NoteDuration duration;

  /// Accidental applied to this note.
  final Accidental accidental;

  /// Whether this is a rest (silence) rather than a pitched note.
  final bool isRest;

  const Note({
    required this.midi,
    this.duration = NoteDuration.quarter,
    this.accidental = Accidental.none,
    this.isRest = false,
  });

  /// Create a rest with the given duration.
  const Note.rest({
    this.duration = NoteDuration.quarter,
  })  : midi = 0,
        accidental = Accidental.none,
        isRest = true;

  /// The octave number (C4 = middle C, MIDI 60).
  int get octave => (midi ~/ 12) - 1;

  /// The note name (pitch class).
  NoteName get noteName {
    final semitone = midi % 12;
    // Map semitone to the closest natural note name.
    return switch (semitone) {
      0 => NoteName.C,
      1 => NoteName.C, // C# / Db
      2 => NoteName.D,
      3 => NoteName.D, // D# / Eb
      4 => NoteName.E,
      5 => NoteName.F,
      6 => NoteName.F, // F# / Gb
      7 => NoteName.G,
      8 => NoteName.G, // G# / Ab
      9 => NoteName.A,
      10 => NoteName.A, // A# / Bb
      11 => NoteName.B,
      _ => NoteName.C,
    };
  }

  /// Display name like "C4", "F#5", "Bb3".
  String get displayName {
    if (isRest) return 'Rest';
    return '${noteName.name}${accidental.symbol}$octave';
  }

  /// Staff position relative to the bottom line (E4) of the treble clef.
  /// Each step = one staff line or space.
  /// E4 = 0, F4 = 1, G4 = 2, A4 = 3, B4 = 4, C5 = 5, D5 = 6, E5 = 7, F5 = 8
  /// Below: D4 = -1, C4 = -2, B3 = -3, A3 = -4, G3 = -5
  int get staffPosition {
    if (isRest) return 4; // Center of staff

    // Map note name to a diatonic step index (C=0, D=1, E=2, F=3, G=4, A=5, B=6)
    final diatonicStep = switch (noteName) {
      NoteName.C => 0,
      NoteName.D => 1,
      NoteName.E => 2,
      NoteName.F => 3,
      NoteName.G => 4,
      NoteName.A => 5,
      NoteName.B => 6,
    };

    // E4 (MIDI 64) is on the bottom line of treble clef (position 0).
    // E4 has octave=4, diatonicStep=2.
    // Position = (octave - 4) * 7 + diatonicStep - 2
    return (octave - 4) * 7 + diatonicStep - 2;
  }

  /// Create a copy with modified fields.
  Note copyWith({
    int? midi,
    NoteDuration? duration,
    Accidental? accidental,
    bool? isRest,
  }) {
    return Note(
      midi: midi ?? this.midi,
      duration: duration ?? this.duration,
      accidental: accidental ?? this.accidental,
      isRest: isRest ?? this.isRest,
    );
  }

  /// Convert a staff position back to MIDI note number.
  /// Assumes treble clef, no accidentals.
  static int staffPositionToMidi(int position) {
    // position 0 = E4 (MIDI 64)
    // Each position is one diatonic step.
    // diatonicStep = (position + 2) % 7 maps to note name
    // octave = 4 + (position + 2) ~/ 7

    final adjusted = position + 2; // offset so C is at 0 in octave 4
    int octave = 4 + adjusted ~/ 7;
    int step = adjusted % 7;

    // Handle negative positions
    if (step < 0) {
      step += 7;
      octave -= 1;
    }

    // Diatonic step to semitone within octave
    final semitones = [0, 2, 4, 5, 7, 9, 11]; // C D E F G A B
    return (octave + 1) * 12 + semitones[step];
  }

  @override
  String toString() => 'Note($displayName, ${duration.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          midi == other.midi &&
          duration == other.duration &&
          accidental == other.accidental &&
          isRest == other.isRest;

  @override
  int get hashCode => Object.hash(midi, duration, accidental, isRest);
}
