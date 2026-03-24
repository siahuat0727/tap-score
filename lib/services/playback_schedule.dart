import '../models/note.dart';
import '../models/score.dart';

class ScorePlaybackStep {
  final int noteIndex;
  final double startSeconds;
  final double durationSeconds;
  final bool isRest;

  const ScorePlaybackStep({
    required this.noteIndex,
    required this.startSeconds,
    required this.durationSeconds,
    required this.isRest,
  });
}

class ScheduledPlaybackNote {
  final int noteIndex;
  final int midi;
  final double startSeconds;
  final double durationSeconds;
  final int velocity;

  const ScheduledPlaybackNote({
    required this.noteIndex,
    required this.midi,
    required this.startSeconds,
    required this.durationSeconds,
    this.velocity = 100,
  });
}

class ScorePlaybackTimeline {
  final List<ScorePlaybackStep> steps;
  final List<ScheduledPlaybackNote> playbackNotes;
  final double totalDurationSeconds;

  const ScorePlaybackTimeline({
    required this.steps,
    required this.playbackNotes,
    required this.totalDurationSeconds,
  });
}

enum ScheduledPlaybackEventType { noteOff, noteOn }

class ScheduledPlaybackEvent {
  final ScheduledPlaybackEventType type;
  final int targetMicros;
  final ScheduledPlaybackNote note;

  const ScheduledPlaybackEvent({
    required this.type,
    required this.targetMicros,
    required this.note,
  });

  int get sortOrder => switch (type) {
    ScheduledPlaybackEventType.noteOff => 0,
    ScheduledPlaybackEventType.noteOn => 1,
  };
}

ScorePlaybackTimeline buildScorePlaybackTimeline(
  Score score, {
  int velocity = 100,
}) {
  final steps = <ScorePlaybackStep>[];
  final playbackNotes = <ScheduledPlaybackNote>[];
  var elapsedSeconds = 0.0;
  final notes = score.notes;

  for (var index = 0; index < notes.length; index++) {
    final note = notes[index];
    final durationSeconds = note.effectiveBeats * score.secondsPerQuarterNote;

    steps.add(
      ScorePlaybackStep(
        noteIndex: index,
        startSeconds: elapsedSeconds,
        durationSeconds: durationSeconds,
        isRest: note.isRest,
      ),
    );

    if (!note.isRest && !_isTieContinuation(notes, index)) {
      var soundingDurationSeconds = durationSeconds;
      var chainIndex = index;
      while (_isTieToNext(notes, chainIndex)) {
        chainIndex += 1;
        soundingDurationSeconds +=
            notes[chainIndex].effectiveBeats * score.secondsPerQuarterNote;
      }
      playbackNotes.add(
        ScheduledPlaybackNote(
          noteIndex: index,
          midi: note.midi,
          startSeconds: elapsedSeconds,
          durationSeconds: soundingDurationSeconds,
          velocity: velocity,
        ),
      );
    }

    elapsedSeconds += durationSeconds;
  }

  return ScorePlaybackTimeline(
    steps: steps,
    playbackNotes: playbackNotes,
    totalDurationSeconds: elapsedSeconds,
  );
}

bool _isTieToNext(List<Note> notes, int index) {
  if (index < 0 || index + 1 >= notes.length) {
    return false;
  }

  final source = notes[index];
  final target = notes[index + 1];
  return source.slurToNext &&
      !source.isRest &&
      !target.isRest &&
      source.midi == target.midi;
}

bool _isTieContinuation(List<Note> notes, int index) {
  if (index <= 0 || index >= notes.length) {
    return false;
  }

  final previous = notes[index - 1];
  final note = notes[index];
  return !previous.isRest &&
      !note.isRest &&
      previous.slurToNext &&
      previous.midi == note.midi;
}

List<ScheduledPlaybackEvent> buildScheduledPlaybackEvents(
  Iterable<ScheduledPlaybackNote> playbackNotes,
) {
  final events = <ScheduledPlaybackEvent>[];

  for (final note in playbackNotes) {
    final startMicros = (note.startSeconds * Duration.microsecondsPerSecond)
        .round();
    final endMicros =
        ((note.startSeconds + note.durationSeconds) *
                Duration.microsecondsPerSecond)
            .round();

    events.add(
      ScheduledPlaybackEvent(
        type: ScheduledPlaybackEventType.noteOn,
        targetMicros: startMicros,
        note: note,
      ),
    );
    events.add(
      ScheduledPlaybackEvent(
        type: ScheduledPlaybackEventType.noteOff,
        targetMicros: endMicros,
        note: note,
      ),
    );
  }

  events.sort((a, b) {
    final targetCompare = a.targetMicros.compareTo(b.targetMicros);
    if (targetCompare != 0) {
      return targetCompare;
    }

    final orderCompare = a.sortOrder.compareTo(b.sortOrder);
    if (orderCompare != 0) {
      return orderCompare;
    }

    return a.note.noteIndex.compareTo(b.note.noteIndex);
  });

  return events;
}
