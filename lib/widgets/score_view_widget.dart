import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../input/editor_shortcuts.dart';
import '../rhythm_test/rhythm_test_models.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';
import 'signature_pickers.dart';

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
          _showTimeSigPicker(context);
        } else {
          notifier.selectTimeSig();
        }
      case 'keySigTap':
        if (!widget.interactive) return;
        if (notifier.selectionKind == SelectionKind.keySig) {
          _showKeySigPicker(context);
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

  void _showTimeSigPicker(BuildContext context) {
    showTimeSigPicker(context, context.read<ScoreNotifier>());
  }

  void _showKeySigPicker(BuildContext context) {
    showKeySigPicker(context, context.read<ScoreNotifier>());
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
            color: AppColors.scoreBackground,
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
        interactive: widget.interactive,
        onMessage: _onJsMessage,
        onReady: (sendRender) {
          setState(() => _sendRender = sendRender);
        },
      ),
    );
  }
}
