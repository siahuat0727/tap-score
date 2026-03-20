import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../input/editor_shortcuts.dart';
import '../state/score_notifier.dart';

/// A scrollable piano keyboard widget for note input.
class PianoKeyboard extends StatelessWidget {
  /// Start MIDI note (default C3 = 48).
  final int startMidi;

  /// End MIDI note (default C6 = 84).
  final int endMidi;

  const PianoKeyboard({super.key, this.startMidi = 48, this.endMidi = 84});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _KeyboardContent(startMidi: startMidi, endMidi: endMidi),
      ),
    );
  }
}

class _KeyboardContent extends StatelessWidget {
  final int startMidi;
  final int endMidi;

  const _KeyboardContent({required this.startMidi, required this.endMidi});

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<ScoreNotifier>();
    final whiteKeys = <Widget>[];
    final blackKeyOverlays = <Widget>[];

    const whiteKeyWidth = 52.0;
    const blackKeyWidth = 34.0;
    const whiteKeyHeight = 150.0;
    const blackKeyHeight = 95.0;

    double xOffset = 0;

    for (int midi = startMidi; midi <= endMidi; midi++) {
      final semitone = midi % 12;
      final isBlack = [1, 3, 6, 8, 10].contains(semitone);

      if (!isBlack) {
        whiteKeys.add(
          _WhiteKey(
            x: xOffset,
            width: whiteKeyWidth,
            height: whiteKeyHeight,
            onTap: () => notifier.insertPitchedNote(midi),
            label: _midiToLabel(midi),
            shortcutLabel: pianoShortcutLabels[midi],
          ),
        );
        xOffset += whiteKeyWidth + 2;
      }
    }

    final totalWidth = xOffset;

    xOffset = 0;
    for (int midi = startMidi; midi <= endMidi; midi++) {
      final semitone = midi % 12;
      final isBlack = [1, 3, 6, 8, 10].contains(semitone);

      if (!isBlack) {
        if (midi + 1 <= endMidi && [1, 3, 6, 8, 10].contains((midi + 1) % 12)) {
          blackKeyOverlays.add(
            _BlackKey(
              x: xOffset + whiteKeyWidth - blackKeyWidth / 2 + 1,
              width: blackKeyWidth,
              height: blackKeyHeight,
              onTap: () => notifier.insertPitchedNote(midi + 1),
            ),
          );
        }
        xOffset += whiteKeyWidth + 2;
      }
    }

    return SizedBox(
      width: totalWidth,
      height: whiteKeyHeight,
      child: Stack(children: [...whiteKeys, ...blackKeyOverlays]),
    );
  }

  String _midiToLabel(int midi) {
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final octave = (midi ~/ 12) - 1;
    return '${names[midi % 12]}$octave';
  }
}

class _WhiteKey extends StatefulWidget {
  final double x;
  final double width;
  final double height;
  final VoidCallback onTap;
  final String label;
  final String? shortcutLabel;

  const _WhiteKey({
    required this.x,
    required this.width,
    required this.height,
    required this.onTap,
    required this.label,
    required this.shortcutLabel,
  });

  @override
  State<_WhiteKey> createState() => _WhiteKeyState();
}

class _WhiteKeyState extends State<_WhiteKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.x,
      top: 0,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isPressed
                  ? [const Color(0xFFE8E4D8), const Color(0xFFD0CCC0)]
                  : [Colors.white, const Color(0xFFF0EDE4)],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(6),
            ),
            border: Border.all(color: const Color(0xFFBBB8B0), width: 1),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(38),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              if (widget.shortcutLabel != null)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F4156),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.shortcutLabel!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlackKey extends StatefulWidget {
  final double x;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _BlackKey({
    required this.x,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<_BlackKey> createState() => _BlackKeyState();
}

class _BlackKeyState extends State<_BlackKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.x,
      top: 0,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isPressed
                  ? [const Color(0xFF444444), const Color(0xFF333333)]
                  : [const Color(0xFF2A2A2A), const Color(0xFF111111)],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(4),
            ),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(128),
                      blurRadius: 4,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
