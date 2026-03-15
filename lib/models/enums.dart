/// Duration of a musical note, relative to a whole note.
enum NoteDuration {
  whole, // 4 beats
  half, // 2 beats
  quarter, // 1 beat
  eighth, // 0.5 beats
  sixteenth; // 0.25 beats

  /// Number of beats this duration represents in 4/4 time.
  double get beats {
    return switch (this) {
      NoteDuration.whole => 4.0,
      NoteDuration.half => 2.0,
      NoteDuration.quarter => 1.0,
      NoteDuration.eighth => 0.5,
      NoteDuration.sixteenth => 0.25,
    };
  }

  /// Display label for UI.
  String get label {
    return switch (this) {
      NoteDuration.whole => '𝅝',
      NoteDuration.half => '𝅗𝅥',
      NoteDuration.quarter => '♩',
      NoteDuration.eighth => '♪',
      NoteDuration.sixteenth => '𝅘𝅥𝅯',
    };
  }
}

/// Accidental applied to a note.
enum Accidental {
  none,
  sharp,
  flat;

  String get symbol {
    return switch (this) {
      Accidental.none => '',
      Accidental.sharp => '♯',
      Accidental.flat => '♭',
    };
  }
}

/// Note name (pitch class) within an octave.
enum NoteName {
  C,
  D,
  E,
  F,
  G,
  A,
  B;

  /// The MIDI offset of the natural note within an octave (C=0).
  int get midiOffset {
    return switch (this) {
      NoteName.C => 0,
      NoteName.D => 2,
      NoteName.E => 4,
      NoteName.F => 5,
      NoteName.G => 7,
      NoteName.A => 9,
      NoteName.B => 11,
    };
  }
}
