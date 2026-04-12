import 'enums.dart';
import 'key_signature.dart';
import 'note.dart';

/// Common time signatures for cycling and picker UI.
const List<(int, int)> commonTimeSignatures = [
  (2, 4),
  (3, 4),
  (4, 4),
  (3, 8),
  (6, 8),
  (5, 4),
  (7, 8),
  (12, 8),
];

/// Represents a musical score — a sequence of notes with tempo and time signature.
class Score {
  /// The notes in order.
  final List<Note> notes;

  /// Beats per measure (top of time signature). Default: 4.
  int beatsPerMeasure;

  /// Beat unit (bottom of time signature). Default: 4 (quarter note).
  int beatUnit;

  /// Tempo in beats per minute.
  double bpm;

  /// Staff clef. Default: treble.
  Clef clef;

  /// Key signature. Default: C major.
  KeySignature keySignature;

  Score({
    List<Note>? notes,
    this.beatsPerMeasure = 4,
    this.beatUnit = 4,
    this.bpm = 120,
    this.clef = Clef.treble,
    this.keySignature = KeySignature.cMajor,
  }) : notes = notes ?? [];

  /// Add a note at the given index. If index is null, append to end.
  void addNote(Note note, [int? index]) {
    if (index != null && index <= notes.length) {
      notes.insert(index, note);
    } else {
      notes.add(note);
    }
  }

  /// Remove the note at the given index.
  void removeAt(int index) {
    if (index >= 0 && index < notes.length) {
      notes.removeAt(index);
    }
  }

  /// Replace the note at the given index.
  void replaceAt(int index, Note note) {
    if (index >= 0 && index < notes.length) {
      notes[index] = note;
    }
  }

  /// Duration of one beat in seconds at the current tempo.
  double get secondsPerBeat => 60.0 / bpm;

  /// Duration of one quarter note in seconds at the current tempo.
  double get secondsPerQuarterNote => secondsPerBeat;

  /// Length of one metronome pulse in quarter-note units.
  double get pulseLengthInQuarterNotes => 4.0 / beatUnit;

  /// Duration of one metronome pulse in seconds.
  double get pulseDurationSeconds =>
      pulseLengthInQuarterNotes * secondsPerQuarterNote;

  /// Duration of one full measure in quarter-note units.
  double get measureLengthInQuarterNotes =>
      beatsPerMeasure * pulseLengthInQuarterNotes;

  /// Duration of one full measure in seconds.
  double get measureDurationSeconds =>
      measureLengthInQuarterNotes * secondsPerQuarterNote;

  /// Create a detached copy of this score.
  Score copy() {
    return Score(
      notes: List<Note>.from(notes),
      beatsPerMeasure: beatsPerMeasure,
      beatUnit: beatUnit,
      bpm: bpm,
      clef: clef,
      keySignature: keySignature,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notes': notes.map((note) => note.toJson()).toList(),
      'beatsPerMeasure': beatsPerMeasure,
      'beatUnit': beatUnit,
      'bpm': bpm,
      'clef': clef.name,
      'keySignature': keySignature.name,
    };
  }

  factory Score.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'];
    if (rawNotes is! List) {
      throw ArgumentError.value(
        json['notes'],
        'notes',
        'Expected a list of notes',
      );
    }

    final beatsPerMeasure = json['beatsPerMeasure'];
    if (beatsPerMeasure is! int) {
      throw ArgumentError.value(
        json['beatsPerMeasure'],
        'beatsPerMeasure',
        'Expected an int',
      );
    }

    final beatUnit = json['beatUnit'];
    if (beatUnit is! int) {
      throw ArgumentError.value(
        json['beatUnit'],
        'beatUnit',
        'Expected an int',
      );
    }

    final bpm = json['bpm'];
    if (bpm is! num) {
      throw ArgumentError.value(json['bpm'], 'bpm', 'Expected a number');
    }

    final clefName = json['clef'];
    if (clefName != null && clefName is! String) {
      throw ArgumentError.value(json['clef'], 'clef', 'Expected a clef name');
    }

    final keySignatureName = json['keySignature'];
    if (keySignatureName is! String) {
      throw ArgumentError.value(
        json['keySignature'],
        'keySignature',
        'Expected a key signature name',
      );
    }

    return Score(
      notes: rawNotes
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw ArgumentError.value(item, 'notes', 'Expected a note map');
            }
            return Note.fromJson(item);
          })
          .toList(growable: true),
      beatsPerMeasure: beatsPerMeasure,
      beatUnit: beatUnit,
      bpm: bpm.toDouble(),
      clef: clefName == null ? Clef.treble : Clef.fromName(clefName),
      keySignature: KeySignature.fromName(keySignatureName),
    );
  }

  @override
  String toString() =>
      'Score(${notes.length} notes, $beatsPerMeasure/$beatUnit, ${bpm}bpm, ${clef.displayName}, ${keySignature.displayName})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Score) return false;
    if (beatsPerMeasure != other.beatsPerMeasure ||
        beatUnit != other.beatUnit ||
        bpm != other.bpm ||
        clef != other.clef ||
        keySignature != other.keySignature ||
        notes.length != other.notes.length) {
      return false;
    }

    for (var index = 0; index < notes.length; index++) {
      if (notes[index] != other.notes[index]) {
        return false;
      }
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(
    beatsPerMeasure,
    beatUnit,
    bpm,
    clef,
    keySignature,
    Object.hashAll(notes),
  );
}
