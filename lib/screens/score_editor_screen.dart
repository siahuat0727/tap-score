import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../input/editor_shortcuts.dart';
import '../state/rhythm_test_notifier.dart';
import '../state/score_notifier.dart';
import '../widgets/duration_selector.dart';
import '../widgets/piano_keyboard.dart';
import '../widgets/playback_controls.dart';
import '../widgets/rhythm_test_panel.dart';
import '../widgets/score_view_widget.dart';

enum _EditorSurfaceMode { compose, rhythmTest }

/// Main editor screen assembling staff, toolbar, and keyboard.
class ScoreEditorScreen extends StatefulWidget {
  const ScoreEditorScreen({super.key});

  @override
  State<ScoreEditorScreen> createState() => _ScoreEditorScreenState();
}

class _ScoreEditorScreenState extends State<ScoreEditorScreen> {
  final FocusNode _focusNode = FocusNode();
  _EditorSurfaceMode _surfaceMode = _EditorSurfaceMode.compose;
  RhythmTestNotifier? _rhythmTestNotifier;

  bool get _isRhythmTestActive => _surfaceMode == _EditorSurfaceMode.rhythmTest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScoreNotifier>().init();
    });
  }

  @override
  void dispose() {
    _rhythmTestNotifier?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _enterRhythmTest() {
    final scoreNotifier = context.read<ScoreNotifier>();
    if (scoreNotifier.score.notes.isEmpty) {
      return;
    }

    scoreNotifier.stop();
    _rhythmTestNotifier?.dispose();
    final rhythmNotifier = RhythmTestNotifier(score: scoreNotifier.score);
    setState(() {
      _surfaceMode = _EditorSurfaceMode.rhythmTest;
      _rhythmTestNotifier = rhythmNotifier;
    });
    rhythmNotifier.init();
    _focusNode.requestFocus();
  }

  void _exitRhythmTest() {
    final rhythmNotifier = _rhythmTestNotifier;
    setState(() {
      _surfaceMode = _EditorSurfaceMode.compose;
      _rhythmTestNotifier = null;
    });
    rhythmNotifier?.dispose();
    _focusNode.requestFocus();
  }

  void _handleRhythmTempoChanged(double bpm) {
    final scoreNotifier = context.read<ScoreNotifier>();
    scoreNotifier.setTempo(bpm);
    _rhythmTestNotifier?.setTempo(bpm);
  }

  bool _handleRendererKeyDown(String? key, String? code) {
    if (!_isRhythmTestActive) {
      return false;
    }

    if (key == 'Enter' || code == 'Enter' || code == 'NumpadEnter') {
      _rhythmTestNotifier?.recordTap();
      return true;
    }

    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_isRhythmTestActive) {
      if (event is KeyDownEvent) {
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          _rhythmTestNotifier?.recordTap();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

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
    final body = _isRhythmTestActive && _rhythmTestNotifier != null
        ? ChangeNotifierProvider.value(
            value: _rhythmTestNotifier!,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controlBarHeight = constraints.maxWidth < 700
                    ? 380.0
                    : 220.0;
                return Column(
                  children: [
                    Expanded(
                      child: Consumer<RhythmTestNotifier>(
                        builder: (context, notifier, _) {
                          return ScoreViewWidget(
                            interactive: false,
                            onRendererKeyDown: _handleRendererKeyDown,
                            rhythmOverlay: notifier.overlayRenderData,
                          );
                        },
                      ),
                    ),
                    Container(height: 1, color: const Color(0xFFE0DDD4)),
                    SizedBox(
                      height: controlBarHeight,
                      child: RhythmTestPanel(
                        onTempoChanged: _handleRhythmTempoChanged,
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        : Column(
            children: [
              Expanded(
                child: ScoreViewWidget(
                  interactive: true,
                  onRendererKeyDown: _handleRendererKeyDown,
                ),
              ),
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
          );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _focusNode.requestFocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(_isRhythmTestActive ? 'Rhythm Test' : 'Tap Score'),
            actions: [
              Consumer<ScoreNotifier>(
                builder: (context, notifier, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _isRhythmTestActive
                            ? 'Exit Rhythm Test'
                            : 'Rhythm Test',
                        onPressed:
                            notifier.score.notes.isEmpty && !_isRhythmTestActive
                            ? null
                            : () {
                                if (_isRhythmTestActive) {
                                  _exitRhythmTest();
                                } else {
                                  _enterRhythmTest();
                                }
                              },
                        icon: Icon(
                          _isRhythmTestActive
                              ? Icons.close_rounded
                              : Icons.timer_outlined,
                        ),
                      ),
                      if (notifier.score.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(
                              '${notifier.score.notes.length} notes',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: const Color(0xFFE8E4D8),
                            side: BorderSide.none,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: SafeArea(child: body),
        ),
      ),
    );
  }
}
