/// Represents a major key signature defined by how many sharps or flats it has.
///
/// Negative values = flats, positive = sharps, zero = C major.
enum KeySignature {
  // Sharps — in circle-of-fifths order
  cMajor(0),
  gMajor(1),
  dMajor(2),
  aMajor(3),
  eMajor(4),
  bMajor(5),
  fSharpMajor(6),

  // Flats — in circle-of-fifths order
  fMajor(-1),
  bbMajor(-2),
  ebMajor(-3),
  abMajor(-4),
  dbMajor(-5),
  gbMajor(-6);

  /// +N for N sharps, -N for N flats.
  final int fifths;
  const KeySignature(this.fifths);

  // ---------------------------------------------------------------------------
  // Pitch alteration data
  // ---------------------------------------------------------------------------

  /// Order in which sharps are added (by semitone within octave).
  static const List<int> _sharpOrder = [6, 1, 8, 3, 10, 5, 0]; // F C G D A E B

  /// Order in which flats are added (by semitone within octave).
  static const List<int> _flatOrder = [
    10,
    3,
    8,
    1,
    6,
    11,
    4,
  ]; // Bb Eb Ab Db Gb Cb Fb

  /// The pitch classes (mod 12) that are raised by a sharp or lowered by a flat
  /// in this key. Empty for C major.
  Set<int> get alteredPitches {
    if (fifths == 0) return {};
    if (fifths > 0) {
      return _sharpOrder.take(fifths).toSet();
    } else {
      return _flatOrder.take(-fifths).toSet();
    }
  }

  /// +1 if the altered pitches are sharped, -1 if flatted, 0 for C major.
  int get accidentalOffset => fifths > 0
      ? 1
      : fifths < 0
      ? -1
      : 0;

  /// Adjust a raw MIDI value so it lands on a diatonic pitch in this key.
  ///
  /// If the input MIDI's pitch class is one semitone *below* a sharpened pitch
  /// (i.e. the user played the natural version), raise it by 1.
  /// If it is one semitone *above* a flattened pitch, lower it by 1.
  int applyToMidi(int midi) {
    if (fifths == 0) return midi;
    final pitchClass = midi % 12;
    if (fifths > 0) {
      // For sharps: if the pitch class is the natural below an altered pitch, raise it.
      final raisedClass = (pitchClass + 1) % 12;
      if (alteredPitches.contains(raisedClass)) return midi + 1;
    } else {
      // For flats: if the pitch class is the natural above an altered pitch, lower it.
      final loweredClass = (pitchClass - 1 + 12) % 12;
      if (alteredPitches.contains(loweredClass)) return midi - 1;
    }
    return midi;
  }

  // ---------------------------------------------------------------------------
  // Display / VexFlow
  // ---------------------------------------------------------------------------

  /// The VexFlow key string (e.g. "C", "G", "D", "F", "Bb").
  String get vexflowKey => switch (this) {
    KeySignature.cMajor => 'C',
    KeySignature.gMajor => 'G',
    KeySignature.dMajor => 'D',
    KeySignature.aMajor => 'A',
    KeySignature.eMajor => 'E',
    KeySignature.bMajor => 'B',
    KeySignature.fSharpMajor => 'F#',
    KeySignature.fMajor => 'F',
    KeySignature.bbMajor => 'Bb',
    KeySignature.ebMajor => 'Eb',
    KeySignature.abMajor => 'Ab',
    KeySignature.dbMajor => 'Db',
    KeySignature.gbMajor => 'Gb',
  };

  /// Human-readable display name.
  String get displayName => switch (this) {
    KeySignature.cMajor => 'C major',
    KeySignature.gMajor => 'G major',
    KeySignature.dMajor => 'D major',
    KeySignature.aMajor => 'A major',
    KeySignature.eMajor => 'E major',
    KeySignature.bMajor => 'B major',
    KeySignature.fSharpMajor => 'F♯ major',
    KeySignature.fMajor => 'F major',
    KeySignature.bbMajor => 'B♭ major',
    KeySignature.ebMajor => 'E♭ major',
    KeySignature.abMajor => 'A♭ major',
    KeySignature.dbMajor => 'D♭ major',
    KeySignature.gbMajor => 'G♭ major',
  };

  // ---------------------------------------------------------------------------
  // Circle-of-fifths navigation
  // ---------------------------------------------------------------------------

  /// All keys in circle-of-fifths order (C … F# for sharps, F … Gb for flats).
  static const List<KeySignature> _circleOrder = [
    gbMajor,
    dbMajor,
    abMajor,
    ebMajor,
    bbMajor,
    fMajor,
    cMajor,
    gMajor,
    dMajor,
    aMajor,
    eMajor,
    bMajor,
    fSharpMajor,
  ];

  int get _circleIndex => _circleOrder.indexOf(this);

  /// Next key clockwise on the circle (add one sharp / remove one flat).
  KeySignature get nextSharp {
    final idx = _circleIndex;
    return _circleOrder[idx < _circleOrder.length - 1 ? idx + 1 : idx];
  }

  /// Next key counter-clockwise on the circle (add one flat / remove one sharp).
  KeySignature get nextFlat {
    final idx = _circleIndex;
    return _circleOrder[idx > 0 ? idx - 1 : idx];
  }

  // ---------------------------------------------------------------------------
  // Diatonic step helpers
  // ---------------------------------------------------------------------------

  /// Root pitch class (semitone mod 12) of this major scale.
  int get rootSemitone => switch (this) {
    cMajor => 0,
    gMajor => 7,
    dMajor => 2,
    aMajor => 9,
    eMajor => 4,
    bMajor => 11,
    fSharpMajor => 6,
    fMajor => 5,
    bbMajor => 10,
    ebMajor => 3,
    abMajor => 8,
    dbMajor => 1,
    gbMajor => 6,
  };

  /// The 7 pitch classes (mod 12) in this major scale, as a set.
  Set<int> get scalePitchClasses {
    const intervals = [0, 2, 4, 5, 7, 9, 11]; // major scale pattern
    return intervals.map((i) => (rootSemitone + i) % 12).toSet();
  }

  /// Move [midi] up or down by one diatonic step within this key.
  ///
  /// [direction] must be 1 (up) or -1 (down).
  /// Walks semitones until hitting a scale pitch class (max 3 steps).
  int diatonicStep(int midi, int direction) {
    final scale = scalePitchClasses;
    int result = midi + direction;
    // Max gap in a major scale is 2 semitones; use 3 for safety.
    while (!scale.contains(result % 12) && (result - midi).abs() <= 3) {
      result += direction;
    }
    return result.clamp(0, 127);
  }
}
