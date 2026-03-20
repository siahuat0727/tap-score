import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/input/editor_shortcuts.dart';
import 'package:tap_score/models/enums.dart';

void main() {
  test('resolves piano key shortcuts to C4-B4', () {
    expect(resolveEditorShortcut(LogicalKeyboardKey.keyD)?.midi, 60);
    expect(resolveEditorShortcut(LogicalKeyboardKey.keyF)?.midi, 62);
    expect(resolveEditorShortcut(LogicalKeyboardKey.keyL)?.midi, 71);
  });

  test('resolves duration and modifier shortcuts', () {
    expect(
      resolveEditorShortcut(LogicalKeyboardKey.digit1)?.duration,
      NoteDuration.whole,
    );
    expect(
      resolveEditorShortcut(LogicalKeyboardKey.digit5)?.duration,
      NoteDuration.sixteenth,
    );
    expect(
      resolveEditorShortcut(LogicalKeyboardKey.digit6)?.kind,
      EditorShortcutKind.toggleDotted,
    );
    expect(
      resolveEditorShortcut(LogicalKeyboardKey.digit9)?.kind,
      EditorShortcutKind.toggleTriplet,
    );
    expect(
      resolveEditorShortcut(LogicalKeyboardKey.backquote)?.kind,
      EditorShortcutKind.restAction,
    );
  });
}
