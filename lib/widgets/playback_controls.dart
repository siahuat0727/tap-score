import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/score_notifier.dart';

/// Playback control bar with play/stop button and tempo slider.
class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScoreNotifier>(
      builder: (context, notifier, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Play / Stop button
              _PlayButton(
                isPlaying: notifier.isPlaying,
                onTap: () {
                  if (notifier.isPlaying) {
                    notifier.stop();
                  } else {
                    notifier.play();
                  }
                },
                enabled: notifier.score.notes.isNotEmpty,
              ),
              const SizedBox(width: 16),
              // Tempo display
              Text(
                '♩ = ${notifier.score.bpm.round()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                ),
              ),
              const SizedBox(width: 8),
              // Tempo slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF2196F3),
                    inactiveTrackColor: const Color(0xFFE0E0E0),
                    thumbColor: const Color(0xFF2196F3),
                    overlayColor: const Color(0xFF2196F3).withAlpha(51),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: notifier.score.bpm,
                    min: 40,
                    max: 240,
                    divisions: 200,
                    label: '${notifier.score.bpm.round()} BPM',
                    onChanged: notifier.isPlaying
                        ? null
                        : (value) => notifier.setTempo(value),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final bool enabled;

  const _PlayButton({
    required this.isPlaying,
    required this.onTap,
    required this.enabled,
  });

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        if (widget.enabled) widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isPlaying
                  ? [const Color(0xFFF44336), const Color(0xFFD32F2F)]
                  : widget.enabled
                      ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
                      : [const Color(0xFFBDBDBD), const Color(0xFF9E9E9E)],
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isPlaying
                        ? const Color(0xFFF44336)
                        : const Color(0xFF4CAF50))
                    .withAlpha(widget.enabled ? 102 : 0),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
