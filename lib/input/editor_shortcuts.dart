import 'package:flutter/services.dart';

import '../models/enums.dart';

enum KeyboardInputMode { keySignatureAware, chromatic }

extension KeyboardInputModePresentation on KeyboardInputMode {
  String get buttonLabel => switch (this) {
    KeyboardInputMode.keySignatureAware => 'Key Sig',
    KeyboardInputMode.chromatic => 'Chromatic',
  };

  String get tooltip => switch (this) {
    KeyboardInputMode.keySignatureAware =>
      'White keys follow the current key signature',
    KeyboardInputMode.chromatic =>
      'White and black keys insert absolute pitches',
  };
}

enum EditorShortcutKind {
  insertPitch,
  restAction,
  setDuration,
  toggleDotted,
  toggleSlur,
  toggleTriplet,
  shiftDown,
  shiftUp,
  toggleInputMode,
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

  const EditorShortcutIntent.shiftDown()
    : this._(kind: EditorShortcutKind.shiftDown);

  const EditorShortcutIntent.shiftUp()
    : this._(kind: EditorShortcutKind.shiftUp);

  const EditorShortcutIntent.toggleInputMode()
    : this._(kind: EditorShortcutKind.toggleInputMode);
}

class PianoKeyHint {
  final String label;
  final bool isShortcutEnabled;
  final bool canTap;
  final bool isShiftHint;

  const PianoKeyHint({
    required this.label,
    required this.isShortcutEnabled,
    required this.canTap,
    this.isShiftHint = false,
  });
}

class _PitchBinding {
  final String label;
  final String code;
  final LogicalKeyboardKey logicalKey;
  final int baseMidi;
  final bool isBlack;

  const _PitchBinding({
    required this.label,
    required this.code,
    required this.logicalKey,
    required this.baseMidi,
    required this.isBlack,
  });
}

const String restShortcutLabel = '`';
const String dottedShortcutLabel = '7';
const String slurShortcutLabel = '8';
const String tripletShortcutLabel = '9';

const int keyboardVisibleStartMidi = 45; // A2
const int keyboardVisibleEndMidi = 86; // D6
const int keyboardMappedStartMidi = 57; // A3
const int keyboardMappedEndMidi = 74; // D5
const int minKeyboardOctaveShift = -1;
const int maxKeyboardOctaveShift = 1;

const Map<NoteDuration, String> durationShortcutLabels = {
  NoteDuration.whole: '1',
  NoteDuration.half: '2',
  NoteDuration.quarter: '3',
  NoteDuration.eighth: '4',
  NoteDuration.sixteenth: '5',
  NoteDuration.thirtySecond: '6',
};

const List<_PitchBinding> _pitchBindings = [
  _PitchBinding(
    label: 'a',
    code: 'KeyA',
    logicalKey: LogicalKeyboardKey.keyA,
    baseMidi: 57,
    isBlack: false,
  ),
  _PitchBinding(
    label: 'w',
    code: 'KeyW',
    logicalKey: LogicalKeyboardKey.keyW,
    baseMidi: 58,
    isBlack: true,
  ),
  _PitchBinding(
    label: 's',
    code: 'KeyS',
    logicalKey: LogicalKeyboardKey.keyS,
    baseMidi: 59,
    isBlack: false,
  ),
  _PitchBinding(
    label: 'd',
    code: 'KeyD',
    logicalKey: LogicalKeyboardKey.keyD,
    baseMidi: 60,
    isBlack: false,
  ),
  _PitchBinding(
    label: 'r',
    code: 'KeyR',
    logicalKey: LogicalKeyboardKey.keyR,
    baseMidi: 61,
    isBlack: true,
  ),
  _PitchBinding(
    label: 'f',
    code: 'KeyF',
    logicalKey: LogicalKeyboardKey.keyF,
    baseMidi: 62,
    isBlack: false,
  ),
  _PitchBinding(
    label: 't',
    code: 'KeyT',
    logicalKey: LogicalKeyboardKey.keyT,
    baseMidi: 63,
    isBlack: true,
  ),
  _PitchBinding(
    label: 'g',
    code: 'KeyG',
    logicalKey: LogicalKeyboardKey.keyG,
    baseMidi: 64,
    isBlack: false,
  ),
  _PitchBinding(
    label: 'h',
    code: 'KeyH',
    logicalKey: LogicalKeyboardKey.keyH,
    baseMidi: 65,
    isBlack: false,
  ),
  _PitchBinding(
    label: 'u',
    code: 'KeyU',
    logicalKey: LogicalKeyboardKey.keyU,
    baseMidi: 66,
    isBlack: true,
  ),
  _PitchBinding(
    label: 'j',
    code: 'KeyJ',
    logicalKey: LogicalKeyboardKey.keyJ,
    baseMidi: 67,
    isBlack: false,
  ),
  _PitchBinding(
    label: 'i',
    code: 'KeyI',
    logicalKey: LogicalKeyboardKey.keyI,
    baseMidi: 68,
    isBlack: true,
  ),
  _PitchBinding(
    label: 'k',
    code: 'KeyK',
    logicalKey: LogicalKeyboardKey.keyK,
    baseMidi: 69,
    isBlack: false,
  ),
  _PitchBinding(
    label: 'o',
    code: 'KeyO',
    logicalKey: LogicalKeyboardKey.keyO,
    baseMidi: 70,
    isBlack: true,
  ),
  _PitchBinding(
    label: 'l',
    code: 'KeyL',
    logicalKey: LogicalKeyboardKey.keyL,
    baseMidi: 71,
    isBlack: false,
  ),
  _PitchBinding(
    label: ';',
    code: 'Semicolon',
    logicalKey: LogicalKeyboardKey.semicolon,
    baseMidi: 72,
    isBlack: false,
  ),
  _PitchBinding(
    label: '[',
    code: 'BracketLeft',
    logicalKey: LogicalKeyboardKey.bracketLeft,
    baseMidi: 73,
    isBlack: true,
  ),
  _PitchBinding(
    label: '\'',
    code: 'Quote',
    logicalKey: LogicalKeyboardKey.quote,
    baseMidi: 74,
    isBlack: false,
  ),
];

bool isBlackMidi(int midi) => switch (midi % 12) {
  1 || 3 || 6 || 8 || 10 => true,
  _ => false,
};

EditorShortcutIntent? resolveEditorShortcut(
  LogicalKeyboardKey key, {
  required KeyboardInputMode inputMode,
  required int octaveShift,
}) {
  final pitchIntent = _resolvePitchBinding(
    _pitchBindingForLogicalKey(key),
    inputMode: inputMode,
    octaveShift: octaveShift,
  );
  if (pitchIntent != null) {
    return pitchIntent;
  }

  return switch (key) {
    LogicalKeyboardKey.keyQ => const EditorShortcutIntent.shiftDown(),
    LogicalKeyboardKey.bracketRight => const EditorShortcutIntent.shiftUp(),
    LogicalKeyboardKey.keyE => const EditorShortcutIntent.toggleInputMode(),
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

EditorShortcutIntent? resolveEditorShortcutCode(
  String code, {
  required KeyboardInputMode inputMode,
  required int octaveShift,
}) {
  final pitchIntent = _resolvePitchBinding(
    _pitchBindingForCode(code),
    inputMode: inputMode,
    octaveShift: octaveShift,
  );
  if (pitchIntent != null) {
    return pitchIntent;
  }

  return switch (code) {
    'KeyQ' => const EditorShortcutIntent.shiftDown(),
    'BracketRight' => const EditorShortcutIntent.shiftUp(),
    'KeyE' => const EditorShortcutIntent.toggleInputMode(),
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

PianoKeyHint describePianoKeyHint(
  int midi, {
  required KeyboardInputMode inputMode,
  required int octaveShift,
}) {
  final canTap = inputMode == KeyboardInputMode.chromatic || !isBlackMidi(midi);
  final windowStart = keyboardMappedStartMidi + (octaveShift * 12);
  final windowEnd = keyboardMappedEndMidi + (octaveShift * 12);

  if (midi < windowStart) {
    return PianoKeyHint(
      label: 'q',
      isShortcutEnabled: octaveShift > minKeyboardOctaveShift,
      canTap: canTap,
      isShiftHint: true,
    );
  }

  if (midi > windowEnd) {
    return PianoKeyHint(
      label: ']',
      isShortcutEnabled: octaveShift < maxKeyboardOctaveShift,
      canTap: canTap,
      isShiftHint: true,
    );
  }

  final binding = _pitchBindingForShiftedMidi(midi, octaveShift);
  if (binding == null) {
    return PianoKeyHint(label: '', isShortcutEnabled: false, canTap: canTap);
  }

  final isShortcutEnabled =
      inputMode == KeyboardInputMode.chromatic || !binding.isBlack;
  return PianoKeyHint(
    label: binding.label,
    isShortcutEnabled: isShortcutEnabled,
    canTap: canTap,
  );
}

_PitchBinding? _pitchBindingForLogicalKey(LogicalKeyboardKey key) {
  for (final binding in _pitchBindings) {
    if (binding.logicalKey == key) {
      return binding;
    }
  }
  return null;
}

_PitchBinding? _pitchBindingForCode(String code) {
  for (final binding in _pitchBindings) {
    if (binding.code == code) {
      return binding;
    }
  }
  return null;
}

_PitchBinding? _pitchBindingForShiftedMidi(int midi, int octaveShift) {
  for (final binding in _pitchBindings) {
    if (binding.baseMidi + (octaveShift * 12) == midi) {
      return binding;
    }
  }
  return null;
}

EditorShortcutIntent? _resolvePitchBinding(
  _PitchBinding? binding, {
  required KeyboardInputMode inputMode,
  required int octaveShift,
}) {
  if (binding == null) {
    return null;
  }

  if (inputMode == KeyboardInputMode.keySignatureAware && binding.isBlack) {
    return null;
  }

  return EditorShortcutIntent.insertPitch(
    binding.baseMidi + (octaveShift * 12),
  );
}
