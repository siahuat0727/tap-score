import 'note.dart';

/// Represents a musical score — a sequence of notes with tempo and time signature.
class Score {
  /// The notes in order.
  final List<Note> notes;

  /// Beats per measure (top of time signature). Default: 4.
  final int beatsPerMeasure;

  /// Beat unit (bottom of time signature). Default: 4 (quarter note).
  final int beatUnit;

  /// Tempo in beats per minute.
  double bpm;

  Score({
    List<Note>? notes,
    this.beatsPerMeasure = 4,
    this.beatUnit = 4,
    this.bpm = 120,
  }) : notes = notes ?? [];

  /// Total duration of the score in beats.
  double get totalBeats {
    return notes.fold(0.0, (sum, note) => sum + note.duration.beats);
  }

  /// Number of measures (rounded up).
  int get measureCount {
    if (notes.isEmpty) return 1;
    return (totalBeats / beatsPerMeasure).ceil().clamp(1, 9999);
  }

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

  /// Get the beat offset of the note at the given index.
  double beatOffsetAt(int index) {
    double offset = 0;
    for (int i = 0; i < index && i < notes.length; i++) {
      offset += notes[i].duration.beats;
    }
    return offset;
  }

  /// Get the measure number (0-based) for the note at the given index.
  int measureForNoteAt(int index) {
    return (beatOffsetAt(index) / beatsPerMeasure).floor();
  }

  /// Get all notes within a given measure (0-based).
  List<Note> notesInMeasure(int measure) {
    final result = <Note>[];
    double beatOffset = 0;
    for (final note in notes) {
      final noteMeasure = (beatOffset / beatsPerMeasure).floor();
      if (noteMeasure == measure) {
        result.add(note);
      } else if (noteMeasure > measure) {
        break;
      }
      beatOffset += note.duration.beats;
    }
    return result;
  }

  /// Duration of one beat in seconds at the current tempo.
  double get secondsPerBeat => 60.0 / bpm;

  @override
  String toString() =>
      'Score(${notes.length} notes, $beatsPerMeasure/$beatUnit, ${bpm}bpm)';
}
