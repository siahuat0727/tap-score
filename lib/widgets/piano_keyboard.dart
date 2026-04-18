import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../input/editor_shortcuts.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import 'input_affordance.dart';

class PianoKeyboardLayout {
  const PianoKeyboardLayout({
    required this.isCompact,
    required this.height,
    required this.controlPanelWidth,
    required this.contentPadding,
    required this.controlPanelPadding,
    required this.whiteKeyHeight,
    required this.blackKeyHeight,
    required this.whiteHintTop,
    required this.whiteLabelBottom,
    required this.blackHintTop,
    required this.labelFontSize,
    required this.controlPanelInnerPadding,
    required this.modeLabelFontSize,
    required this.sectionTitleFontSize,
    required this.modeToggleWidth,
    required this.modeToggleHeight,
    required this.arrowButtonSize,
    required this.controlSectionGap,
    required this.arrowButtonGap,
  });

  static const PianoKeyboardLayout regular = PianoKeyboardLayout(
    isCompact: false,
    height: 220,
    controlPanelWidth: 132,
    contentPadding: EdgeInsets.fromLTRB(12, 10, 12, 10),
    controlPanelPadding: EdgeInsets.fromLTRB(4, 12, 12, 12),
    whiteKeyHeight: 180,
    blackKeyHeight: 102,
    whiteHintTop: 104,
    whiteLabelBottom: 8,
    blackHintTop: 66,
    labelFontSize: 10,
    controlPanelInnerPadding: 8,
    modeLabelFontSize: 12,
    sectionTitleFontSize: 12,
    modeToggleWidth: 68,
    modeToggleHeight: 34,
    arrowButtonSize: 36,
    controlSectionGap: 6,
    arrowButtonGap: 2,
  );

  static const PianoKeyboardLayout compact = PianoKeyboardLayout(
    isCompact: true,
    height: 156,
    controlPanelWidth: 108,
    contentPadding: EdgeInsets.fromLTRB(10, 8, 10, 8),
    controlPanelPadding: EdgeInsets.fromLTRB(4, 8, 8, 8),
    whiteKeyHeight: 128,
    blackKeyHeight: 78,
    whiteHintTop: 72,
    whiteLabelBottom: 6,
    blackHintTop: 48,
    labelFontSize: 9,
    controlPanelInnerPadding: 6,
    modeLabelFontSize: 11,
    sectionTitleFontSize: 11,
    modeToggleWidth: 60,
    modeToggleHeight: 30,
    arrowButtonSize: 32,
    controlSectionGap: 4,
    arrowButtonGap: 2,
  );

  final bool isCompact;
  final double height;
  final double controlPanelWidth;
  final EdgeInsets contentPadding;
  final EdgeInsets controlPanelPadding;
  final double whiteKeyHeight;
  final double blackKeyHeight;
  final double whiteHintTop;
  final double whiteLabelBottom;
  final double blackHintTop;
  final double labelFontSize;
  final double controlPanelInnerPadding;
  final double modeLabelFontSize;
  final double sectionTitleFontSize;
  final double modeToggleWidth;
  final double modeToggleHeight;
  final double arrowButtonSize;
  final double controlSectionGap;
  final double arrowButtonGap;
}

/// A scrollable piano keyboard widget for note input.
class PianoKeyboard extends StatelessWidget {
  final int startMidi;
  final int endMidi;
  final PianoKeyboardLayout layout;

  const PianoKeyboard({
    super.key,
    this.startMidi = keyboardVisibleStartMidi,
    this.endMidi = keyboardVisibleEndMidi,
    this.layout = PianoKeyboardLayout.regular,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: layout.height,
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
              padding: layout.contentPadding,
              child: _KeyboardContent(
                startMidi: startMidi,
                endMidi: endMidi,
                layout: layout,
              ),
            ),
          ),
          SizedBox(
            width: layout.controlPanelWidth,
            child: Padding(
              padding: layout.controlPanelPadding,
              child: _KeyboardControlPanel(layout: layout),
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
  final PianoKeyboardLayout layout;

  const _KeyboardContent({
    required this.startMidi,
    required this.endMidi,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ScoreNotifier>();
    final affordanceProfile = resolveInputAffordanceProfile(
      context,
      compact: layout.isCompact,
    );
    final showsShortcutHints = affordanceProfile.showsKeyboardAffordances;
    final whiteKeys = <Widget>[];
    final blackKeys = <Widget>[];

    const whiteKeyWidth = 52.0;
    const blackKeyWidth = 34.0;
    const gap = 2.0;

    double xOffset = 0;
    for (int midi = startMidi; midi <= endMidi; midi++) {
      if (isBlackMidi(midi)) {
        continue;
      }

      final hint = showsShortcutHints
          ? describePianoKeyHint(
              midi,
              inputMode: notifier.keyboardInputMode,
              octaveShift: notifier.keyboardOctaveShift,
              clef: notifier.score.clef,
            )
          : const PianoKeyHint(
              label: '',
              isShortcutEnabled: false,
              canTap: false,
            );
      whiteKeys.add(
        _WhiteKey(
          key: ValueKey('piano-white-$midi'),
          x: xOffset,
          width: whiteKeyWidth,
          height: layout.whiteKeyHeight,
          label: _whiteKeyLabel(notifier, midi),
          hint: hint,
          hintTop: layout.whiteHintTop,
          labelBottom: layout.whiteLabelBottom,
          labelFontSize: layout.labelFontSize,
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

      final hint = showsShortcutHints
          ? describePianoKeyHint(
              nextMidi,
              inputMode: notifier.keyboardInputMode,
              octaveShift: notifier.keyboardOctaveShift,
              clef: notifier.score.clef,
            )
          : const PianoKeyHint(
              label: '',
              isShortcutEnabled: false,
              canTap: false,
            );
      blackKeys.add(
        _BlackKey(
          key: ValueKey('piano-black-$nextMidi'),
          x: xOffset + whiteKeyWidth - blackKeyWidth / 2 + 1,
          width: blackKeyWidth,
          height: layout.blackKeyHeight,
          hint: hint,
          hintTop: layout.blackHintTop,
          onTap: _tapHandler(notifier, nextMidi),
        ),
      );
      xOffset += whiteKeyWidth + gap;
    }

    return SizedBox(
      width: totalWidth,
      height: layout.whiteKeyHeight,
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
  final double hintTop;
  final double labelBottom;
  final double labelFontSize;
  final VoidCallback? onTap;

  const _WhiteKey({
    super.key,
    required this.x,
    required this.width,
    required this.height,
    required this.label,
    required this.hint,
    required this.hintTop,
    required this.labelBottom,
    required this.labelFontSize,
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
                  top: widget.hintTop,
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
                  padding: EdgeInsets.only(bottom: widget.labelBottom),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.labelFontSize,
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
  final double hintTop;
  final VoidCallback? onTap;

  const _BlackKey({
    super.key,
    required this.x,
    required this.width,
    required this.height,
    required this.hint,
    required this.hintTop,
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
                  top: widget.hintTop,
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
  const _KeyboardControlPanel({required this.layout});

  final PianoKeyboardLayout layout;

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, _) {
        final affordanceProfile = resolveInputAffordanceProfile(
          context,
          compact: layout.isCompact,
        );
        final navigationControls = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ArrowButton(
                  size: layout.arrowButtonSize,
                  key: const ValueKey('keyboard-nav-left'),
                  icon: Icons.keyboard_arrow_left_rounded,
                  tooltip: 'Move selection left',
                  onPressed: notifier.moveSelectionLeft,
                ),
                SizedBox(width: layout.arrowButtonGap),
                _ArrowButton(
                  size: layout.arrowButtonSize,
                  key: const ValueKey('keyboard-nav-right'),
                  icon: Icons.keyboard_arrow_right_rounded,
                  tooltip: 'Move selection right',
                  onPressed: notifier.moveSelectionRight,
                ),
              ],
            ),
            SizedBox(height: layout.arrowButtonGap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ArrowButton(
                  size: layout.arrowButtonSize,
                  key: const ValueKey('keyboard-nav-up'),
                  icon: Icons.keyboard_arrow_up_rounded,
                  tooltip: 'Move pitch up',
                  onPressed: () => notifier.adjustSelection(1),
                ),
                SizedBox(width: layout.arrowButtonGap),
                _ArrowButton(
                  size: layout.arrowButtonSize,
                  key: const ValueKey('keyboard-nav-down'),
                  icon: Icons.keyboard_arrow_down_rounded,
                  tooltip: 'Move pitch down',
                  onPressed: () => notifier.adjustSelection(-1),
                ),
              ],
            ),
          ],
        );

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: layout.isCompact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            _KeyboardModeToggle(
              notifier: notifier,
              layout: layout,
              showShortcutHint: affordanceProfile.showsKeyboardAffordances,
            ),
            SizedBox(height: layout.controlSectionGap),
            Text(
              'Navigate',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.keyboardControlText,
                fontSize: layout.sectionTitleFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: layout.isCompact ? 2 : 4),
            if (layout.isCompact)
              Center(child: navigationControls)
            else
              Expanded(child: Center(child: navigationControls)),
          ],
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.keyboardControlPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.keyboardControlBorder),
          ),
          child: Padding(
            padding: EdgeInsets.all(layout.controlPanelInnerPadding),
            child: layout.isCompact
                ? SingleChildScrollView(child: content)
                : content,
          ),
        );
      },
    );
  }
}

class _KeyboardModeToggle extends StatelessWidget {
  final ScoreNotifier notifier;
  final PianoKeyboardLayout layout;
  final bool showShortcutHint;

  const _KeyboardModeToggle({
    required this.notifier,
    required this.layout,
    required this.showShortcutHint,
  });

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
          style: TextStyle(
            color: AppColors.keyboardControlText,
            fontSize: layout.modeLabelFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: layout.controlSectionGap + 2),
        Material(
          color: Colors.transparent,
          child: Center(
            child: InkWell(
              onTap: notifier.toggleKeyboardInputMode,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                key: const ValueKey('keyboard-mode-toggle'),
                width: layout.modeToggleWidth,
                height: layout.modeToggleHeight,
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
                                  fontSize: layout.isCompact ? 9 : 10,
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
                                  fontSize: layout.isCompact ? 9 : 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showShortcutHint)
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
  final double size;

  const _ArrowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.size,
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
            width: size,
            height: size,
            child: Icon(icon, size: size - 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
