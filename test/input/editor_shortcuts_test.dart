import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/input/editor_shortcuts.dart';
import 'package:tap_score/models/enums.dart';

EditorShortcutIntent? _resolveEvent({
  LogicalKeyboardKey? logicalKey,
  String? code,
  String? character,
  KeyboardInputMode inputMode = KeyboardInputMode.keySignatureAware,
  int octaveShift = 0,
  Clef clef = Clef.treble,
}) {
  return resolveEditorShortcutEvent(
    EditorShortcutEvent(
      logicalKey: logicalKey,
      code: code,
      character: character,
    ),
    inputMode: inputMode,
    octaveShift: octaveShift,
    clef: clef,
  );
}

EditorShortcutIntent? _resolveKey(
  LogicalKeyboardKey key, {
  KeyboardInputMode inputMode = KeyboardInputMode.keySignatureAware,
  int octaveShift = 0,
  Clef clef = Clef.treble,
  String? character,
}) {
  return resolveEditorShortcut(
    key,
    inputMode: inputMode,
    octaveShift: octaveShift,
    clef: clef,
    character: character,
  );
}

EditorShortcutIntent? _resolveCode(
  String code, {
  KeyboardInputMode inputMode = KeyboardInputMode.keySignatureAware,
  int octaveShift = 0,
  Clef clef = Clef.treble,
  String? character,
}) {
  return resolveEditorShortcutCode(
    code,
    inputMode: inputMode,
    octaveShift: octaveShift,
    clef: clef,
    character: character,
  );
}

void main() {
  test('default mode resolves white-key shortcuts in the A3-D5 window', () {
    expect(_resolveKey(LogicalKeyboardKey.keyA)?.midi, 57);
    expect(_resolveKey(LogicalKeyboardKey.keyD)?.midi, 60);
    expect(_resolveKey(LogicalKeyboardKey.quote, character: '\'')?.midi, 74);
  });

  test('default mode disables black-key shortcuts', () {
    expect(_resolveKey(LogicalKeyboardKey.keyW), isNull);
    expect(_resolveKey(LogicalKeyboardKey.keyR), isNull);
    expect(_resolveCode('BracketLeft'), isNull);
  });

  test('chromatic mode resolves black-key shortcuts', () {
    expect(
      _resolveKey(
        LogicalKeyboardKey.keyW,
        inputMode: KeyboardInputMode.chromatic,
      )?.midi,
      58,
    );
    expect(
      _resolveKey(
        LogicalKeyboardKey.keyR,
        inputMode: KeyboardInputMode.chromatic,
      )?.midi,
      61,
    );
    expect(
      _resolveCode('BracketLeft', inputMode: KeyboardInputMode.chromatic)?.midi,
      73,
    );
  });

  test('octave shift moves the entire mapping window', () {
    expect(_resolveKey(LogicalKeyboardKey.keyD, octaveShift: -1)?.midi, 48);
    expect(_resolveKey(LogicalKeyboardKey.keyD, octaveShift: 1)?.midi, 72);
    expect(
      _resolveKey(
        LogicalKeyboardKey.keyR,
        inputMode: KeyboardInputMode.chromatic,
        octaveShift: 1,
      )?.midi,
      73,
    );
  });

  test('bass clef shifts the shortcut window down an octave', () {
    final bounds = keyboardShiftBoundsForClef(Clef.bass);
    expect(bounds.minShift, 0);
    expect(bounds.maxShift, 2);
    expect(_resolveKey(LogicalKeyboardKey.keyD, clef: Clef.bass)?.midi, 48);
    expect(
      _resolveKey(
        LogicalKeyboardKey.quote,
        clef: Clef.bass,
        character: '\'',
      )?.midi,
      62,
    );
    expect(
      _resolveKey(
        LogicalKeyboardKey.keyR,
        inputMode: KeyboardInputMode.chromatic,
        clef: Clef.bass,
      )?.midi,
      49,
    );
    expect(
      _resolveKey(
        LogicalKeyboardKey.keyD,
        clef: Clef.bass,
        octaveShift: 2,
      )?.midi,
      72,
    );
  });

  test('resolves mode toggle and mapping shift shortcuts', () {
    expect(
      _resolveKey(LogicalKeyboardKey.keyE)?.kind,
      EditorShortcutKind.toggleInputMode,
    );
    expect(
      _resolveKey(LogicalKeyboardKey.keyQ)?.kind,
      EditorShortcutKind.shiftDown,
    );
    expect(
      _resolveKey(LogicalKeyboardKey.bracketRight)?.kind,
      EditorShortcutKind.shiftUp,
    );
  });

  test('resolves duration and modifier shortcuts', () {
    expect(
      _resolveKey(LogicalKeyboardKey.digit1)?.duration,
      NoteDuration.whole,
    );
    expect(
      _resolveKey(LogicalKeyboardKey.digit5)?.duration,
      NoteDuration.sixteenth,
    );
    expect(
      _resolveKey(LogicalKeyboardKey.digit6)?.duration,
      NoteDuration.thirtySecond,
    );
    expect(
      _resolveKey(LogicalKeyboardKey.digit7)?.kind,
      EditorShortcutKind.toggleDotted,
    );
    expect(
      _resolveKey(LogicalKeyboardKey.digit8)?.kind,
      EditorShortcutKind.toggleSlur,
    );
    expect(
      _resolveKey(LogicalKeyboardKey.digit9)?.kind,
      EditorShortcutKind.toggleTriplet,
    );
    expect(
      _resolveKey(LogicalKeyboardKey.backquote)?.kind,
      EditorShortcutKind.restAction,
    );
  });

  test('resolves browser key codes for forwarded iframe shortcuts', () {
    expect(_resolveCode('KeyD')?.midi, 60);
    expect(
      _resolveCode('KeyW', inputMode: KeyboardInputMode.chromatic)?.midi,
      58,
    );
    expect(_resolveCode('Quote', character: '\'')?.midi, 74);
    expect(_resolveCode('Digit1')?.duration, NoteDuration.whole);
    expect(_resolveCode('Digit6')?.duration, NoteDuration.thirtySecond);
    expect(_resolveCode('KeyE')?.kind, EditorShortcutKind.toggleInputMode);
    expect(_resolveCode('KeyQ')?.kind, EditorShortcutKind.shiftDown);
    expect(_resolveCode('BracketRight')?.kind, EditorShortcutKind.shiftUp);
    expect(_resolveCode('Digit8')?.kind, EditorShortcutKind.toggleSlur);
    expect(_resolveCode('Backquote')?.kind, EditorShortcutKind.restAction);
  });

  test('quote pitch binding only resolves the apostrophe character', () {
    expect(
      _resolveEvent(
        logicalKey: LogicalKeyboardKey.quote,
        character: '\'',
      )?.midi,
      74,
    );
    expect(_resolveEvent(code: 'Quote', character: '\'')?.midi, 74);
    expect(
      _resolveEvent(logicalKey: LogicalKeyboardKey.quote, character: '"'),
      isNull,
    );
    expect(_resolveEvent(code: 'Quote', character: '"'), isNull);
    expect(_resolveEvent(logicalKey: LogicalKeyboardKey.quote), isNull);
    expect(_resolveEvent(code: 'Quote'), isNull);
  });

  test('piano key hints reflect mapped keys and shift zones', () {
    final whiteHint = describePianoKeyHint(
      60,
      inputMode: KeyboardInputMode.keySignatureAware,
      octaveShift: 0,
    );
    expect(whiteHint.label, 'd');
    expect(whiteHint.isShortcutEnabled, isTrue);
    expect(whiteHint.canTap, isTrue);
    expect(whiteHint.isShiftHint, isFalse);

    final blackHint = describePianoKeyHint(
      61,
      inputMode: KeyboardInputMode.keySignatureAware,
      octaveShift: 0,
    );
    expect(blackHint.label, 'r');
    expect(blackHint.isShortcutEnabled, isFalse);
    expect(blackHint.canTap, isFalse);

    final leftShiftHint = describePianoKeyHint(
      45,
      inputMode: KeyboardInputMode.keySignatureAware,
      octaveShift: 0,
    );
    expect(leftShiftHint.label, 'q');
    expect(leftShiftHint.isShortcutEnabled, isTrue);
    expect(leftShiftHint.canTap, isTrue);
    expect(leftShiftHint.isShiftHint, isTrue);
  });

  test('bass clef piano key hints use the lower shortcut window', () {
    final whiteHint = describePianoKeyHint(
      48,
      inputMode: KeyboardInputMode.keySignatureAware,
      octaveShift: 0,
      clef: Clef.bass,
    );
    expect(whiteHint.label, 'd');
    expect(whiteHint.isShortcutEnabled, isTrue);

    final rightShiftHint = describePianoKeyHint(
      74,
      inputMode: KeyboardInputMode.keySignatureAware,
      octaveShift: 0,
      clef: Clef.bass,
    );
    expect(rightShiftHint.label, ']');
    expect(rightShiftHint.isShiftHint, isTrue);

    final finalShiftHint = describePianoKeyHint(
      86,
      inputMode: KeyboardInputMode.keySignatureAware,
      octaveShift: 2,
      clef: Clef.bass,
    );
    expect(finalShiftHint.label, '\'');
    expect(finalShiftHint.isShiftHint, isFalse);

    final blockedShiftHint = describePianoKeyHint(
      87,
      inputMode: KeyboardInputMode.keySignatureAware,
      octaveShift: 2,
      clef: Clef.bass,
    );
    expect(blockedShiftHint.label, ']');
    expect(blockedShiftHint.isShortcutEnabled, isFalse);
    expect(blockedShiftHint.isShiftHint, isTrue);
  });
}
