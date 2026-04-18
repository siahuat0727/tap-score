import 'dart:convert';

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
    this.blockRendererPointerInput = false,
    this.onRendererKeyDown,
    this.onRendererReady,
    this.rhythmOverlay,
    this.playbackIndex,
    super.key,
  });

  final bool interactive;
  final bool blockRendererPointerInput;
  final bool Function(String? key, String? code, bool repeat)?
  onRendererKeyDown;
  final VoidCallback? onRendererReady;
  final RhythmOverlayRenderData? rhythmOverlay;
  final int? playbackIndex;

  @override
  State<ScoreViewWidget> createState() => _ScoreViewWidgetState();
}

class ScoreRendererCommandController {
  String? _lastStaticSignature;
  String? _lastRhythmOverlaySignature;
  int? _lastPlaybackIndex;

  void reset() {
    _lastStaticSignature = null;
    _lastRhythmOverlaySignature = null;
    _lastPlaybackIndex = null;
  }

  List<Map<String, dynamic>> buildCommands({
    required Map<String, dynamic> staticPayload,
    required Map<String, dynamic>? rhythmOverlayPayload,
    required int playbackIndex,
    bool forceStatic = false,
  }) {
    final commands = <Map<String, dynamic>>[];
    final staticSignature = jsonEncode(staticPayload);
    final rhythmOverlaySignature = jsonEncode(rhythmOverlayPayload);
    final needsStaticRender =
        forceStatic || staticSignature != _lastStaticSignature;

    if (needsStaticRender) {
      commands.add({'type': 'renderScoreStatic', ...staticPayload});
      _lastStaticSignature = staticSignature;
    }

    if (needsStaticRender ||
        rhythmOverlaySignature != _lastRhythmOverlaySignature) {
      commands.add({
        'type': 'updateRhythmOverlay',
        'rhythmTest': rhythmOverlayPayload,
      });
      _lastRhythmOverlaySignature = rhythmOverlaySignature;
    }

    if (needsStaticRender || playbackIndex != _lastPlaybackIndex) {
      commands.add({
        'type': 'updatePlaybackIndex',
        'playbackIndex': playbackIndex,
      });
      _lastPlaybackIndex = playbackIndex;
    }

    return commands;
  }
}

class _ScoreViewWidgetState extends State<ScoreViewWidget> {
  /// Function provided by the platform renderer once it's ready.
  void Function(Map<String, dynamic> payload)? _sendCommand;
  final ScoreRendererCommandController _commandController =
      ScoreRendererCommandController();
  ScoreNotifier? _notifier;

  // ---------------------------------------------------------------------------
  // JS → Dart message handler
  // ---------------------------------------------------------------------------
  void _onJsMessage(Map<String, dynamic> data) {
    final notifier = context.read<ScoreNotifier>();
    final type = data['type'] as String?;
    switch (type) {
      case 'ready':
        _flushRendererCommands(forceStatic: true);
      case 'noteTap':
        if (!widget.interactive) return;
        final index = data['index'] as int?;
        if (index != null) notifier.selectNote(index);
      case 'clefTap':
        if (!widget.interactive) return;
        if (notifier.selectionKind == SelectionKind.clef) {
          _showClefPicker(context);
        } else {
          notifier.selectClef();
        }
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
        final repeat = data['repeat'] == true;
        final handledByParent = widget.onRendererKeyDown?.call(
          key,
          code,
          repeat,
        );
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
          clef: notifier.score.clef,
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
  Map<String, dynamic> _buildStaticPayload(ScoreNotifier notifier) {
    final score = notifier.score;
    final clef = score.clef;
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

    final label = notifier.currentScoreLabel;
    var title = label == 'Draft' ? '' : label;
    if (title.isNotEmpty && notifier.hasUnsavedChanges) {
      title += ' \u2022';
    }

    return {
      'clef': clef.vexflowName,
      'restAnchorPitch': clef.restAnchorPitch,
      'beatsPerMeasure': score.beatsPerMeasure,
      'beatUnit': score.beatUnit,
      'keySignatureStr': keySig.vexflowKey,
      'alteredPitches': keySig.alteredPitches.toList(),
      'accidentalOffset': keySig.accidentalOffset,
      'notes': notesList,
      'selectedIndex': notifier.selectedIndex ?? -1,
      'cursorIndex': notifier.cursorIndex,
      'selectionKind': notifier.selectionKind?.name ?? '',
      'showsRhythmOverlay': widget.rhythmOverlay != null,
      'title': title,
      'bpm': score.bpm.round(),
    };
  }

  void _flushRendererCommands({bool forceStatic = false}) {
    final notifier = _notifier;
    final send = _sendCommand;
    if (notifier == null || send == null) {
      return;
    }

    final commands = _commandController.buildCommands(
      staticPayload: _buildStaticPayload(notifier),
      rhythmOverlayPayload: widget.rhythmOverlay?.toPayload(),
      playbackIndex: widget.playbackIndex ?? notifier.playbackIndex,
      forceStatic: forceStatic,
    );
    for (final command in commands) {
      send(command);
    }
  }

  void _handleScoreNotifierChanged() {
    _flushRendererCommands();
  }

  // ---------------------------------------------------------------------------
  // Pickers (opened on tap-again when already selected)
  // ---------------------------------------------------------------------------

  void _showClefPicker(BuildContext context) {
    showClefPicker(context, context.read<ScoreNotifier>());
  }

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<ScoreNotifier>();
    if (_notifier == notifier) {
      return;
    }
    _notifier?.removeListener(_handleScoreNotifierChanged);
    _notifier = notifier;
    notifier.addListener(_handleScoreNotifierChanged);
    _flushRendererCommands(forceStatic: true);
  }

  @override
  void didUpdateWidget(covariant ScoreViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rhythmOverlay != widget.rhythmOverlay ||
        oldWidget.playbackIndex != widget.playbackIndex) {
      _flushRendererCommands();
    }
  }

  @override
  void dispose() {
    _notifier?.removeListener(_handleScoreNotifierChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pointerInputEnabled =
        !widget.blockRendererPointerInput &&
        (widget.interactive ||
            (widget.rhythmOverlay?.enablesInspection ?? false));

    return Container(
      key: const ValueKey('score-view-surface'),
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      clipBehavior: Clip.hardEdge,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: buildScoreRenderer(
          interactive: widget.interactive,
          pointerInputEnabled: pointerInputEnabled,
          onMessage: _onJsMessage,
          onReady: (sendCommand) {
            _sendCommand = sendCommand;
            _commandController.reset();
            widget.onRendererReady?.call();
            _flushRendererCommands(forceStatic: true);
          },
        ),
      ),
    );
  }
}
