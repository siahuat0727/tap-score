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

  /// Original pitch to restore when toggling a rest back into a note.
  final int? sourceMidi;

  /// Whether this note draws a slur to the next logical note.
  final bool slurToNext;

  const Note({
    required this.midi,
    this.duration = NoteDuration.quarter,
    this.accidental = Accidental.none,
    this.isRest = false,
    this.isDotted = false,
    this.tripletGroupId,
    this.sourceMidi,
    this.slurToNext = false,
  });

  /// Create a rest with the given duration.
  const Note.rest({
    this.duration = NoteDuration.quarter,
    this.isDotted = false,
    this.tripletGroupId,
    this.sourceMidi,
    this.slurToNext = false,
  }) : midi = 0,
       accidental = Accidental.none,
       isRest = true;

  /// Beat count before tuplets are applied.
  double get writtenBeats {
    var beats = duration.beats;
    if (isDotted) beats *= 1.5;
    return beats;
  }

  /// Actual beat count accounting for dot and triplet modifiers.
  double get effectiveBeats {
    var beats = writtenBeats;
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
    int? Function()? sourceMidi,
    bool? slurToNext,
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
      sourceMidi: sourceMidi != null ? sourceMidi() : this.sourceMidi,
      slurToNext: slurToNext ?? this.slurToNext,
    );
  }

  /// Convert this note to a rest while preserving timing modifiers.
  Note asRest() {
    return Note.rest(
      duration: duration,
      isDotted: isDotted,
      tripletGroupId: tripletGroupId,
      sourceMidi: sourceMidi ?? (isRest ? null : midi),
      slurToNext: false,
    );
  }

  /// Convert this rest back to a pitched note.
  Note asPitched({int defaultMidi = 60}) {
    return Note(
      midi: sourceMidi ?? defaultMidi,
      duration: duration,
      isDotted: isDotted,
      tripletGroupId: tripletGroupId,
      slurToNext: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'midi': midi,
      'duration': duration.name,
      'accidental': accidental.name,
      'isRest': isRest,
      'isDotted': isDotted,
      'tripletGroupId': tripletGroupId,
      'sourceMidi': sourceMidi,
      'slurToNext': slurToNext,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    final isRest = json['isRest'];
    if (isRest is! bool) {
      throw ArgumentError.value(json['isRest'], 'isRest', 'Expected a bool');
    }

    final durationName = json['duration'];
    if (durationName is! String) {
      throw ArgumentError.value(
        json['duration'],
        'duration',
        'Expected a duration name',
      );
    }

    final accidentalName = json['accidental'];
    if (accidentalName is! String) {
      throw ArgumentError.value(
        json['accidental'],
        'accidental',
        'Expected an accidental name',
      );
    }

    final midi = json['midi'];
    if (midi is! int) {
      throw ArgumentError.value(json['midi'], 'midi', 'Expected an int');
    }

    final isDotted = json['isDotted'];
    if (isDotted is! bool) {
      throw ArgumentError.value(
        json['isDotted'],
        'isDotted',
        'Expected a bool',
      );
    }

    final slurToNext = json['slurToNext'];
    if (slurToNext is! bool) {
      throw ArgumentError.value(
        json['slurToNext'],
        'slurToNext',
        'Expected a bool',
      );
    }

    final tripletGroupId = json['tripletGroupId'];
    if (tripletGroupId != null && tripletGroupId is! int) {
      throw ArgumentError.value(
        json['tripletGroupId'],
        'tripletGroupId',
        'Expected an int or null',
      );
    }

    final sourceMidi = json['sourceMidi'];
    if (sourceMidi != null && sourceMidi is! int) {
      throw ArgumentError.value(
        json['sourceMidi'],
        'sourceMidi',
        'Expected an int or null',
      );
    }

    return Note(
      midi: midi,
      duration: NoteDuration.fromName(durationName),
      accidental: Accidental.fromName(accidentalName),
      isRest: isRest,
      isDotted: isDotted,
      tripletGroupId: tripletGroupId,
      sourceMidi: sourceMidi,
      slurToNext: slurToNext,
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
          tripletGroupId == other.tripletGroupId &&
          sourceMidi == other.sourceMidi &&
          slurToNext == other.slurToNext;

  @override
  int get hashCode => Object.hash(
    midi,
    duration,
    accidental,
    isRest,
    isDotted,
    tripletGroupId,
    sourceMidi,
    slurToNext,
  );
}
