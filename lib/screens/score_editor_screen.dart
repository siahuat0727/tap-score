import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  @override
  void initState() {
    super.initState();
    // Initialize the audio service after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScoreNotifier>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded, size: 24, color: Color(0xFF3F51B5)),
            SizedBox(width: 8),
            Text('Tap Score'),
          ],
        ),
        actions: [
          Consumer<ScoreNotifier>(
            builder: (context, notifier, _) {
              if (notifier.score.notes.isEmpty) return const SizedBox.shrink();
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
            // Staff takes up the available space
            const Expanded(child: ScoreViewWidget()),
            // Divider
            Container(height: 1, color: const Color(0xFFE0DDD4)),
            // Toolbar: duration selector + playback controls
            Container(
              color: const Color(0xFFF0EDE4),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [DurationSelector(), PlaybackControls()],
              ),
            ),
            // Piano keyboard at the bottom
            const PianoKeyboard(),
          ],
        ),
      ),
    );
  }
}
