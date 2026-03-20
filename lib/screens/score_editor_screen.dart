import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../input/editor_shortcuts.dart';
import '../state/score_notifier.dart';
import '../widgets/score_view_widget.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/duration_selector.dart';
import '../widgets/playback_controls.dart';

/// Main editor screen assembling staff, toolbar, and keyboard.
class ScoreEditorScreen extends StatefulWidget {
  const ScoreEditorScreen({super.key});

  @override
  State<ScoreEditorScreen> createState() => _ScoreEditorScreenState();
}

class _ScoreEditorScreenState extends State<ScoreEditorScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Initialize the audio service after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScoreNotifier>().init();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final notifier = context.read<ScoreNotifier>();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      notifier.moveSelectionLeft();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      notifier.moveSelectionRight();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      notifier.adjustSelection(1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      notifier.adjustSelection(-1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      notifier.deleteSelected();
      return KeyEventResult.handled;
    }

    final shortcut = resolveEditorShortcut(key);
    if (shortcut == null) {
      return KeyEventResult.ignored;
    }

    switch (shortcut.kind) {
      case EditorShortcutKind.insertPitch:
        notifier.insertPitchedNote(shortcut.midi!);
      case EditorShortcutKind.restAction:
        notifier.handleRestAction();
      case EditorShortcutKind.setDuration:
        notifier.setDuration(shortcut.duration!);
      case EditorShortcutKind.toggleDotted:
        notifier.toggleDottedMode();
      case EditorShortcutKind.toggleSlur:
        notifier.toggleSlurMode();
      case EditorShortcutKind.toggleTriplet:
        notifier.toggleTripletMode();
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _focusNode.requestFocus(),
        child: Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_note_rounded,
                  size: 24,
                  color: Color(0xFF3F51B5),
                ),
                SizedBox(width: 8),
                Text('Tap Score'),
              ],
            ),
            actions: [
              Consumer<ScoreNotifier>(
                builder: (context, notifier, _) {
                  if (notifier.score.notes.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(
                        '${notifier.score.notes.length} notes',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: const Color(0xFFE8E4D8),
                      side: BorderSide.none,
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                const Expanded(child: ScoreViewWidget()),
                Container(height: 1, color: const Color(0xFFE0DDD4)),
                Container(
                  color: const Color(0xFFF0EDE4),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [DurationSelector(), PlaybackControls()],
                  ),
                ),
                const PianoKeyboard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
