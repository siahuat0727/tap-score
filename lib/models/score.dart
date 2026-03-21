import 'note.dart';
import 'key_signature.dart';

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

  /// Key signature. Default: C major.
  KeySignature keySignature;

  Score({
    List<Note>? notes,
    this.beatsPerMeasure = 4,
    this.beatUnit = 4,
    this.bpm = 120,
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
      keySignature: keySignature,
    );
  }

  @override
  String toString() =>
      'Score(${notes.length} notes, $beatsPerMeasure/$beatUnit, ${bpm}bpm, ${keySignature.displayName})';
}
