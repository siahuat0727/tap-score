import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../input/editor_shortcuts.dart';
import '../models/key_signature.dart';
import '../models/score.dart';
import '../rhythm_test/rhythm_test_models.dart';
import '../state/score_notifier.dart';

import 'score_renderer_stub.dart'
    if (dart.library.js_interop) 'score_renderer_web.dart'
    if (dart.library.io) 'score_renderer_native.dart';

/// A widget that renders the musical score using VexFlow.
///
/// On native platforms, uses `webview_flutter`.
/// On web, uses an iframe via `HtmlElementView`.
///
/// All UI logic (pickers, payload construction, message handling) is shared.
class ScoreViewWidget extends StatefulWidget {
  const ScoreViewWidget({
    this.interactive = true,
    this.onRendererKeyDown,
    this.rhythmOverlay,
    super.key,
  });

  final bool interactive;
  final bool Function(String? key, String? code)? onRendererKeyDown;
  final RhythmOverlayRenderData? rhythmOverlay;

  @override
  State<ScoreViewWidget> createState() => _ScoreViewWidgetState();
}

class _ScoreViewWidgetState extends State<ScoreViewWidget> {
  /// Function provided by the platform renderer once it's ready.
  void Function(Map<String, dynamic> payload)? _sendRender;

  /// Common time signatures shown in the picker.
  static const List<(int, int)> _commonTimeSigs = commonTimeSignatures;

  // ---------------------------------------------------------------------------
  // JS → Dart message handler
  // ---------------------------------------------------------------------------
  void _onJsMessage(Map<String, dynamic> data) {
    final notifier = context.read<ScoreNotifier>();
    final type = data['type'] as String?;
    switch (type) {
      case 'ready':
        _renderNow(notifier);
      case 'noteTap':
        if (!widget.interactive) return;
        final index = data['index'] as int?;
        if (index != null) notifier.selectNote(index);
      case 'bgTap':
        if (!widget.interactive) return;
        notifier.selectNote(null);
      case 'timeSigTap':
        if (!widget.interactive) return;
        if (notifier.selectionKind == SelectionKind.timeSig) {
          _showTimeSigPicker();
        } else {
          notifier.selectTimeSig();
        }
      case 'keySigTap':
        if (!widget.interactive) return;
        if (notifier.selectionKind == SelectionKind.keySig) {
          _showKeySigPicker();
        } else {
          notifier.selectKeySig();
        }
      case 'keydown':
        final key = data['key'] as String?;
        final code = data['code'] as String?;
        final handledByParent = widget.onRendererKeyDown?.call(key, code);
        if (handledByParent == true) {
          return;
        }
        if (!widget.interactive) {
          return;
        }
        final shortcut = resolveEditorShortcutEvent(
          EditorShortcutEvent(code: code, character: key),
          inputMode: notifier.keyboardInputMode,
          octaveShift: notifier.keyboardOctaveShift,
        );
        if (shortcut != null) {
          notifier.handleEditorShortcut(shortcut);
          return;
        }
        switch (key) {
          case 'ArrowLeft':
            notifier.moveSelectionLeft();
          case 'ArrowRight':
            notifier.moveSelectionRight();
          case 'ArrowUp':
            notifier.adjustSelection(1);
          case 'ArrowDown':
            notifier.adjustSelection(-1);
          case 'Delete' || 'Backspace':
            notifier.deleteSelected();
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Dart → JS render
  // ---------------------------------------------------------------------------
  void _renderNow(ScoreNotifier notifier) {
    final send = _sendRender;
    if (send == null) return;

    final score = notifier.score;
    final keySig = score.keySignature;

    final notesList = score.notes.map((note) {
      return {
        'midi': note.midi,
        'duration': note.duration.name,
        'beats': note.effectiveBeats,
        'isRest': note.isRest,
        'isDotted': note.isDotted,
        'slurToNext': note.slurToNext,
        'tripletGroupId': note.tripletGroupId,
      };
    }).toList();

    send({
      'type': 'render',
      'beatsPerMeasure': score.beatsPerMeasure,
      'beatUnit': score.beatUnit,
      'keySignatureStr': keySig.vexflowKey,
      'alteredPitches': keySig.alteredPitches.toList(),
      'accidentalOffset': keySig.accidentalOffset,
      'notes': notesList,
      'selectedIndex': notifier.selectedIndex ?? -1,
      'cursorIndex': notifier.cursorIndex,
      'playbackIndex': notifier.playbackIndex,
      'selectionKind': notifier.selectionKind?.name ?? '',
      'rhythmTest': widget.rhythmOverlay?.toPayload(),
    });
  }

  // ---------------------------------------------------------------------------
  // Pickers (opened on tap-again when already selected)
  // ---------------------------------------------------------------------------

  void _showTimeSigPicker() {
    final notifier = context.read<ScoreNotifier>();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Time Signature',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _commonTimeSigs.map((sig) {
                  final (beats, unit) = sig;
                  final isCurrent =
                      notifier.score.beatsPerMeasure == beats &&
                      notifier.score.beatUnit == unit;
                  return GestureDetector(
                    onTap: () {
                      notifier.setTimeSignature(beats, unit);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF1976d2)
                            : const Color(0xFFF0EDE4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFF1976d2)
                              : const Color(0xFFDDDAD0),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$beats',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                              color: isCurrent
                                  ? Colors.white
                                  : const Color(0xFF333333),
                            ),
                          ),
                          Container(
                            height: 1.5,
                            width: 28,
                            color: isCurrent
                                ? Colors.white70
                                : const Color(0xFF888888),
                            margin: const EdgeInsets.symmetric(vertical: 2),
                          ),
                          Text(
                            '$unit',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                              color: isCurrent
                                  ? Colors.white
                                  : const Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showKeySigPicker() {
    final notifier = context.read<ScoreNotifier>();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Key Signature',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: KeySignature.values.map((key) {
                  final isCurrent = notifier.score.keySignature == key;
                  return GestureDetector(
                    onTap: () {
                      notifier.setKeySignature(key);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF1976d2)
                            : const Color(0xFFF0EDE4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFF1976d2)
                              : const Color(0xFFDDDAD0),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            key.vexflowKey,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Colors.white
                                  : const Color(0xFF333333),
                            ),
                          ),
                          Text(
                            key.fifths == 0
                                ? '♮'
                                : key.fifths > 0
                                ? '♯' * key.fifths.abs()
                                : '♭' * key.fifths.abs(),
                            style: TextStyle(
                              fontSize: 11,
                              color: isCurrent
                                  ? Colors.white70
                                  : const Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, child) {
        // Trigger re-render whenever score state changes.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _renderNow(notifier);
        });

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.all(16),
          clipBehavior: Clip.hardEdge,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // The platform renderer is stable (never rebuilt by Consumer)
            // because it's passed via the `child` parameter.
            child: child!,
          ),
        );
      },
      // Build the platform renderer once — it survives Consumer rebuilds.
      child: buildScoreRenderer(
        onMessage: _onJsMessage,
        onReady: (sendRender) {
          setState(() => _sendRender = sendRender);
        },
      ),
    );
  }
}
