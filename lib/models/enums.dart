enum Clef {
  treble,
  bass;

  String get vexflowName => name;

  String get displayName => switch (this) {
    Clef.treble => 'Treble',
    Clef.bass => 'Bass',
  };

  int get defaultRestoreMidi => switch (this) {
    Clef.treble => 60,
    Clef.bass => 48,
  };

  int get keyboardShortcutMidiOffset => switch (this) {
    Clef.treble => 0,
    Clef.bass => -12,
  };

  String get restAnchorPitch => switch (this) {
    Clef.treble => 'b/4',
    Clef.bass => 'd/3',
  };

  static Clef fromName(String name) {
    return Clef.values.firstWhere(
      (clef) => clef.name == name,
      orElse: () => throw ArgumentError.value(name, 'name', 'Unsupported clef'),
    );
  }
}

/// Duration of a musical note, relative to a whole note.
enum NoteDuration {
  whole, // 4 beats
  half, // 2 beats
  quarter, // 1 beat
  eighth, // 0.5 beats
  sixteenth, // 0.25 beats
  thirtySecond; // 0.125 beats

  /// Number of beats this duration represents in 4/4 time.
  double get beats {
    return switch (this) {
      NoteDuration.whole => 4.0,
      NoteDuration.half => 2.0,
      NoteDuration.quarter => 1.0,
      NoteDuration.eighth => 0.5,
      NoteDuration.sixteenth => 0.25,
      NoteDuration.thirtySecond => 0.125,
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
      NoteDuration.thirtySecond => '𝅘𝅥𝅰',
    };
  }

  /// Display label for a rest of this duration.
  String get restLabel {
    return switch (this) {
      NoteDuration.whole => '𝄻',
      NoteDuration.half => '𝄼',
      NoteDuration.quarter => '𝄽',
      NoteDuration.eighth => '𝄾',
      NoteDuration.sixteenth => '𝄿',
      NoteDuration.thirtySecond => '𝅀',
    };
  }

  static NoteDuration fromName(String name) {
    return NoteDuration.values.firstWhere(
      (duration) => duration.name == name,
      orElse: () =>
          throw ArgumentError.value(name, 'name', 'Unsupported note duration'),
    );
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

  static Accidental fromName(String name) {
    return Accidental.values.firstWhere(
      (accidental) => accidental.name == name,
      orElse: () =>
          throw ArgumentError.value(name, 'name', 'Unsupported accidental'),
    );
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
