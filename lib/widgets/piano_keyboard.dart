import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../input/editor_shortcuts.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';

/// A scrollable piano keyboard widget for note input.
class PianoKeyboard extends StatelessWidget {
  final int startMidi;
  final int endMidi;

  const PianoKeyboard({
    super.key,
    this.startMidi = keyboardVisibleStartMidi,
    this.endMidi = keyboardVisibleEndMidi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.keyboardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _KeyboardContent(startMidi: startMidi, endMidi: endMidi),
            ),
          ),
          const SizedBox(
            width: 132,
            child: Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 12, 12),
              child: _KeyboardControlPanel(),
            ),
          ),
        ],
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
    final notifier = context.watch<ScoreNotifier>();
    final whiteKeys = <Widget>[];
    final blackKeys = <Widget>[];

    const whiteKeyWidth = 52.0;
    const blackKeyWidth = 34.0;
    const whiteKeyHeight = 180.0;
    const blackKeyHeight = 102.0;
    const gap = 2.0;

    double xOffset = 0;
    for (int midi = startMidi; midi <= endMidi; midi++) {
      if (isBlackMidi(midi)) {
        continue;
      }

      final hint = describePianoKeyHint(
        midi,
        inputMode: notifier.keyboardInputMode,
        octaveShift: notifier.keyboardOctaveShift,
        clef: notifier.score.clef,
      );
      whiteKeys.add(
        _WhiteKey(
          key: ValueKey('piano-white-$midi'),
          x: xOffset,
          width: whiteKeyWidth,
          height: whiteKeyHeight,
          label: _whiteKeyLabel(notifier, midi),
          hint: hint,
          onTap: _tapHandler(notifier, midi),
        ),
      );
      xOffset += whiteKeyWidth + gap;
    }

    final totalWidth = xOffset;

    xOffset = 0;
    for (int midi = startMidi; midi <= endMidi; midi++) {
      if (isBlackMidi(midi)) {
        continue;
      }

      final nextMidi = midi + 1;
      if (nextMidi > endMidi || !isBlackMidi(nextMidi)) {
        xOffset += whiteKeyWidth + gap;
        continue;
      }

      final hint = describePianoKeyHint(
        nextMidi,
        inputMode: notifier.keyboardInputMode,
        octaveShift: notifier.keyboardOctaveShift,
        clef: notifier.score.clef,
      );
      blackKeys.add(
        _BlackKey(
          key: ValueKey('piano-black-$nextMidi'),
          x: xOffset + whiteKeyWidth - blackKeyWidth / 2 + 1,
          width: blackKeyWidth,
          height: blackKeyHeight,
          hint: hint,
          onTap: _tapHandler(notifier, nextMidi),
        ),
      );
      xOffset += whiteKeyWidth + gap;
    }

    return SizedBox(
      width: totalWidth,
      height: whiteKeyHeight,
      child: Stack(children: [...whiteKeys, ...blackKeys]),
    );
  }

  VoidCallback? _tapHandler(ScoreNotifier notifier, int midi) {
    if (!notifier.canTapPianoKey(midi)) {
      return null;
    }
    return () => notifier.handlePianoTap(midi);
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

  String _whiteKeyLabel(ScoreNotifier notifier, int midi) {
    final labelMidi =
        notifier.keyboardInputMode == KeyboardInputMode.keySignatureAware
        ? notifier.resolveInputMidi(midi)
        : midi;
    return _midiToLabel(labelMidi);
  }
}

class _WhiteKey extends StatefulWidget {
  final double x;
  final double width;
  final double height;
  final String label;
  final PianoKeyHint hint;
  final VoidCallback? onTap;

  const _WhiteKey({
    super.key,
    required this.x,
    required this.width,
    required this.height,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  State<_WhiteKey> createState() => _WhiteKeyState();
}

class _WhiteKeyState extends State<_WhiteKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    return Positioned(
      left: widget.x,
      top: 0,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel: isEnabled
            ? () => setState(() => _isPressed = false)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: !isEnabled
                  ? [const Color(0xFFE6E2D8), const Color(0xFFD5D0C4)]
                  : _isPressed
                  ? [const Color(0xFFE8E4D8), const Color(0xFFD0CCC0)]
                  : [Colors.white, const Color(0xFFF0EDE4)],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(6),
            ),
            border: Border.all(
              color: isEnabled
                  ? AppColors.whiteKeyBorderEnabled
                  : AppColors.whiteKeyBorderDisabled,
              width: 1,
            ),
            boxShadow: !isEnabled || _isPressed
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
              if (widget.hint.label.isNotEmpty)
                Positioned(
                  top: 104,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ShortcutBadge(
                      label: widget.hint.label,
                      enabled: widget.hint.isShortcutEnabled,
                      isShiftHint: widget.hint.isShiftHint,
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
                      color: isEnabled
                          ? Colors.grey[600]
                          : AppColors.whiteKeyDisabledLabel,
                      fontWeight: FontWeight.w600,
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
  final PianoKeyHint hint;
  final VoidCallback? onTap;

  const _BlackKey({
    super.key,
    required this.x,
    required this.width,
    required this.height,
    required this.hint,
    required this.onTap,
  });

  @override
  State<_BlackKey> createState() => _BlackKeyState();
}

class _BlackKeyState extends State<_BlackKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onTap != null;
    return Positioned(
      left: widget.x,
      top: 0,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel: isEnabled
            ? () => setState(() => _isPressed = false)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: !isEnabled
                  ? [const Color(0xFF6D6D6D), const Color(0xFF515151)]
                  : _isPressed
                  ? [const Color(0xFF444444), const Color(0xFF333333)]
                  : [const Color(0xFF2A2A2A), const Color(0xFF111111)],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(4),
            ),
            boxShadow: !isEnabled || _isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(128),
                      blurRadius: 4,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              if (widget.hint.label.isNotEmpty)
                Positioned(
                  top: 66,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ShortcutBadge(
                      label: widget.hint.label,
                      enabled: widget.hint.isShortcutEnabled,
                      isShiftHint: widget.hint.isShiftHint,
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

class _ShortcutBadge extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isShiftHint;

  const _ShortcutBadge({
    required this.label,
    required this.enabled,
    required this.isShiftHint,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = !enabled
        ? AppColors.keyBadgeDisabled
        : isShiftHint
        ? AppColors.keyBadgeShift
        : AppColors.keyBadgeDefault;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _KeyboardControlPanel extends StatelessWidget {
  const _KeyboardControlPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.keyboardControlPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.keyboardControlBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KeyboardModeToggle(notifier: notifier),
                const SizedBox(height: 6),
                const Text(
                  'Navigate',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.keyboardControlText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ArrowButton(
                              key: const ValueKey('keyboard-nav-left'),
                              icon: Icons.keyboard_arrow_left_rounded,
                              tooltip: 'Move selection left',
                              onPressed: notifier.moveSelectionLeft,
                            ),
                            const SizedBox(width: 2),
                            _ArrowButton(
                              key: const ValueKey('keyboard-nav-right'),
                              icon: Icons.keyboard_arrow_right_rounded,
                              tooltip: 'Move selection right',
                              onPressed: notifier.moveSelectionRight,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ArrowButton(
                              key: const ValueKey('keyboard-nav-up'),
                              icon: Icons.keyboard_arrow_up_rounded,
                              tooltip: 'Move pitch up',
                              onPressed: () => notifier.adjustSelection(1),
                            ),
                            const SizedBox(width: 2),
                            _ArrowButton(
                              key: const ValueKey('keyboard-nav-down'),
                              icon: Icons.keyboard_arrow_down_rounded,
                              tooltip: 'Move pitch down',
                              onPressed: () => notifier.adjustSelection(-1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KeyboardModeToggle extends StatelessWidget {
  final ScoreNotifier notifier;

  const _KeyboardModeToggle({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isKeySig =
        notifier.keyboardInputMode == KeyboardInputMode.keySignatureAware;
    final modeLabel = isKeySig ? 'Key Sig' : 'Chromatic';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          modeLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.keyboardControlText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: Center(
            child: InkWell(
              onTap: notifier.toggleKeyboardInputMode,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                key: const ValueKey('keyboard-mode-toggle'),
                width: 68,
                height: 34,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.keyboardToggleTrack,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.keyboardToggleBorder),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: isKeySig
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: 0.42,
                        heightFactor: 1,
                        child: Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: isKeySig
                                ? AppColors.keyboardToggleKeySig
                                : AppColors.keyboardToggleChromatic,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(38),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                'Key',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(
                                    isKeySig ? 230 : 100,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Chr',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(
                                    isKeySig ? 100 : 230,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      child: IgnorePointer(
                        child: _ShortcutBadge(
                          label: 'e',
                          enabled: true,
                          isShiftHint: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ArrowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.keyboardArrowButton,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
