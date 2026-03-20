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

  /// Whether this note is dotted (duration × 1.5).
  final bool isDotted;

  /// Triplet group ID. Notes sharing the same non-null ID form a triplet
  /// (3 equal notes in the time of 2).
  final int? tripletGroupId;

  const Note({
    required this.midi,
    this.duration = NoteDuration.quarter,
    this.accidental = Accidental.none,
    this.isRest = false,
    this.isDotted = false,
    this.tripletGroupId,
  });

  /// Create a rest with the given duration.
  const Note.rest({
    this.duration = NoteDuration.quarter,
    this.isDotted = false,
    this.tripletGroupId,
  }) : midi = 0,
       accidental = Accidental.none,
       isRest = true;

  /// Actual beat count accounting for dot and triplet modifiers.
  double get effectiveBeats {
    var beats = duration.beats;
    if (isDotted) beats *= 1.5;
    if (tripletGroupId != null) beats *= 2.0 / 3.0;
    return beats;
  }

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

  /// Create a copy with modified fields.
  Note copyWith({
    int? midi,
    NoteDuration? duration,
    Accidental? accidental,
    bool? isRest,
    bool? isDotted,
    int? Function()? tripletGroupId,
  }) {
    return Note(
      midi: midi ?? this.midi,
      duration: duration ?? this.duration,
      accidental: accidental ?? this.accidental,
      isRest: isRest ?? this.isRest,
      isDotted: isDotted ?? this.isDotted,
      tripletGroupId: tripletGroupId != null
          ? tripletGroupId()
          : this.tripletGroupId,
    );
  }

  /// Convert this note to a rest while preserving timing modifiers.
  Note asRest() {
    return Note.rest(
      duration: duration,
      isDotted: isDotted,
      tripletGroupId: tripletGroupId,
    );
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
          isRest == other.isRest &&
          isDotted == other.isDotted &&
          tripletGroupId == other.tripletGroupId;

  @override
  int get hashCode =>
      Object.hash(midi, duration, accidental, isRest, isDotted, tripletGroupId);
}
