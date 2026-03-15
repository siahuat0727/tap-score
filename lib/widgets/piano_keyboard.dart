import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/score_notifier.dart';

/// A scrollable piano keyboard widget for note input.
class PianoKeyboard extends StatelessWidget {
  /// Start MIDI note (default C3 = 48).
  final int startMidi;

  /// End MIDI note (default C6 = 84).
  final int endMidi;

  const PianoKeyboard({
    super.key,
    this.startMidi = 48,
    this.endMidi = 84,
  });

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
        child: _buildKeyboard(context),
      ),
    );
  }

  Widget _buildKeyboard(BuildContext context) {
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
        // White key
        whiteKeys.add(
          _WhiteKey(
            midi: midi,
            x: xOffset,
            width: whiteKeyWidth,
            height: whiteKeyHeight,
            onTap: () => notifier.insertNote(midi),
            label: _midiToLabel(midi),
          ),
        );
        xOffset += whiteKeyWidth + 2;
      }
    }

    // Second pass for black keys
    xOffset = 0;
    for (int midi = startMidi; midi <= endMidi; midi++) {
      final semitone = midi % 12;
      final isBlack = [1, 3, 6, 8, 10].contains(semitone);

      if (!isBlack) {
        // Check if next semitone is a black key
        if (midi + 1 <= endMidi && [1, 3, 6, 8, 10].contains((midi + 1) % 12)) {
          blackKeyOverlays.add(
            _BlackKey(
              midi: midi + 1,
              x: xOffset + whiteKeyWidth - blackKeyWidth / 2 + 1,
              width: blackKeyWidth,
              height: blackKeyHeight,
              onTap: () => notifier.insertNote(midi + 1),
            ),
          );
        }
        xOffset += whiteKeyWidth + 2;
      }
    }

    final totalWidth = xOffset;

    return SizedBox(
      width: totalWidth,
      height: whiteKeyHeight,
      child: Stack(
        children: [
          // White keys
          ...whiteKeys,
          // Black keys on top
          ...blackKeyOverlays,
        ],
      ),
    );
  }

  String _midiToLabel(int midi) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midi ~/ 12) - 1;
    return '${names[midi % 12]}$octave';
  }
}

class _WhiteKey extends StatefulWidget {
  final int midi;
  final double x;
  final double width;
  final double height;
  final VoidCallback onTap;
  final String label;

  const _WhiteKey({
    required this.midi,
    required this.x,
    required this.width,
    required this.height,
    required this.onTap,
    required this.label,
  });

  @override
  State<_WhiteKey> createState() => _WhiteKeyState();
}

class _WhiteKeyState extends State<_WhiteKey> with SingleTickerProviderStateMixin {
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
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
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
          alignment: Alignment.bottomCenter,
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
    );
  }
}

class _BlackKey extends StatefulWidget {
  final int midi;
  final double x;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _BlackKey({
    required this.midi,
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
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
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
