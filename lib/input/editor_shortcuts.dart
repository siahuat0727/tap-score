import 'package:flutter/services.dart';

import '../models/enums.dart';

enum EditorShortcutKind {
  insertPitch,
  restAction,
  setDuration,
  toggleDotted,
  toggleSlur,
  toggleTriplet,
}

class EditorShortcutIntent {
  final EditorShortcutKind kind;
  final int? midi;
  final NoteDuration? duration;

  const EditorShortcutIntent._({required this.kind, this.midi, this.duration});

  const EditorShortcutIntent.insertPitch(int midi)
    : this._(kind: EditorShortcutKind.insertPitch, midi: midi);

  const EditorShortcutIntent.restAction()
    : this._(kind: EditorShortcutKind.restAction);

  const EditorShortcutIntent.setDuration(NoteDuration duration)
    : this._(kind: EditorShortcutKind.setDuration, duration: duration);

  const EditorShortcutIntent.toggleDotted()
    : this._(kind: EditorShortcutKind.toggleDotted);

  const EditorShortcutIntent.toggleSlur()
    : this._(kind: EditorShortcutKind.toggleSlur);

  const EditorShortcutIntent.toggleTriplet()
    : this._(kind: EditorShortcutKind.toggleTriplet);
}

const String restShortcutLabel = '`';
const String dottedShortcutLabel = '7';
const String slurShortcutLabel = '8';
const String tripletShortcutLabel = '9';

const Map<NoteDuration, String> durationShortcutLabels = {
  NoteDuration.whole: '1',
  NoteDuration.half: '2',
  NoteDuration.quarter: '3',
  NoteDuration.eighth: '4',
  NoteDuration.sixteenth: '5',
  NoteDuration.thirtySecond: '6',
};

const Map<int, String> pianoShortcutLabels = {
  60: 'd',
  62: 'f',
  64: 'g',
  65: 'h',
  67: 'j',
  69: 'k',
  71: 'l',
};

EditorShortcutIntent? resolveEditorShortcut(LogicalKeyboardKey key) {
  return switch (key) {
    LogicalKeyboardKey.keyD => const EditorShortcutIntent.insertPitch(60),
    LogicalKeyboardKey.keyF => const EditorShortcutIntent.insertPitch(62),
    LogicalKeyboardKey.keyG => const EditorShortcutIntent.insertPitch(64),
    LogicalKeyboardKey.keyH => const EditorShortcutIntent.insertPitch(65),
    LogicalKeyboardKey.keyJ => const EditorShortcutIntent.insertPitch(67),
    LogicalKeyboardKey.keyK => const EditorShortcutIntent.insertPitch(69),
    LogicalKeyboardKey.keyL => const EditorShortcutIntent.insertPitch(71),
    LogicalKeyboardKey.backquote => const EditorShortcutIntent.restAction(),
    LogicalKeyboardKey.digit1 => const EditorShortcutIntent.setDuration(
      NoteDuration.whole,
    ),
    LogicalKeyboardKey.digit2 => const EditorShortcutIntent.setDuration(
      NoteDuration.half,
    ),
    LogicalKeyboardKey.digit3 => const EditorShortcutIntent.setDuration(
      NoteDuration.quarter,
    ),
    LogicalKeyboardKey.digit4 => const EditorShortcutIntent.setDuration(
      NoteDuration.eighth,
    ),
    LogicalKeyboardKey.digit5 => const EditorShortcutIntent.setDuration(
      NoteDuration.sixteenth,
    ),
    LogicalKeyboardKey.digit6 => const EditorShortcutIntent.setDuration(
      NoteDuration.thirtySecond,
    ),
    LogicalKeyboardKey.digit7 => const EditorShortcutIntent.toggleDotted(),
    LogicalKeyboardKey.digit8 => const EditorShortcutIntent.toggleSlur(),
    LogicalKeyboardKey.digit9 => const EditorShortcutIntent.toggleTriplet(),
    _ => null,
  };
}

EditorShortcutIntent? resolveEditorShortcutCode(String code) {
  return switch (code) {
    'KeyD' => const EditorShortcutIntent.insertPitch(60),
    'KeyF' => const EditorShortcutIntent.insertPitch(62),
    'KeyG' => const EditorShortcutIntent.insertPitch(64),
    'KeyH' => const EditorShortcutIntent.insertPitch(65),
    'KeyJ' => const EditorShortcutIntent.insertPitch(67),
    'KeyK' => const EditorShortcutIntent.insertPitch(69),
    'KeyL' => const EditorShortcutIntent.insertPitch(71),
    'Backquote' => const EditorShortcutIntent.restAction(),
    'Digit1' => const EditorShortcutIntent.setDuration(NoteDuration.whole),
    'Digit2' => const EditorShortcutIntent.setDuration(NoteDuration.half),
    'Digit3' => const EditorShortcutIntent.setDuration(NoteDuration.quarter),
    'Digit4' => const EditorShortcutIntent.setDuration(NoteDuration.eighth),
    'Digit5' => const EditorShortcutIntent.setDuration(NoteDuration.sixteenth),
    'Digit6' => const EditorShortcutIntent.setDuration(
      NoteDuration.thirtySecond,
    ),
    'Digit7' => const EditorShortcutIntent.toggleDotted(),
    'Digit8' => const EditorShortcutIntent.toggleSlur(),
    'Digit9' => const EditorShortcutIntent.toggleTriplet(),
    _ => null,
  };
}
