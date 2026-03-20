import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/models/enums.dart';
import 'package:tap_score/models/note.dart';
import 'package:tap_score/state/score_notifier.dart';

void main() {
  test('rest mode inserts a rest when duration is chosen', () {
    final notifier = ScoreNotifier();

    notifier.handleRestAction();
    expect(notifier.restMode, isTrue);

    notifier.setDuration(NoteDuration.half);

    expect(notifier.restMode, isFalse);
    expect(notifier.currentDuration, NoteDuration.half);
    expect(notifier.score.notes, hasLength(1));
    expect(notifier.score.notes.single.isRest, isTrue);
    expect(notifier.score.notes.single.duration, NoteDuration.half);
    expect(notifier.cursorIndex, 1);
  });

  test('rest action converts selected note to a rest preserving timing', () {
    final notifier = ScoreNotifier();

    notifier.score.addNote(
      const Note(
        midi: 60,
        duration: NoteDuration.eighth,
        isDotted: true,
        tripletGroupId: 7,
      ),
    );
    notifier.selectNote(0);

    notifier.handleRestAction();

    final note = notifier.score.notes.single;
    expect(note.isRest, isTrue);
    expect(note.duration, NoteDuration.eighth);
    expect(note.isDotted, isTrue);
    expect(note.tripletGroupId, 7);
    expect(notifier.selectedIndex, 0);
  });
}
