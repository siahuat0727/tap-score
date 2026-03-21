import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/rhythm_test_notifier.dart';

class RhythmTestPanel extends StatelessWidget {
  const RhythmTestPanel({required this.onTempoChanged, super.key});

  final ValueChanged<double> onTempoChanged;

  @override
  Widget build(BuildContext context) {
    return Consumer<RhythmTestNotifier>(
      builder: (context, notifier, _) {
        final result = notifier.result;
        final averageErrorBeats =
            result?.shiftedAverageAbsoluteErrorSeconds == null
            ? null
            : result!.shiftedAverageAbsoluteErrorSeconds! /
                  notifier.timeline.pulseDurationSeconds;
        final shiftBeats = result == null
            ? null
            : result.appliedShiftSeconds /
                  notifier.timeline.pulseDurationSeconds;

        return ColoredBox(
          color: const Color(0xFFF0EDE4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 700;

                final summary = _SummaryWrap(
                  phase: notifier.phase,
                  matchedLabel: result == null
                      ? 'Not run'
                      : '${result.matchedCount} / ${result.expectedCount}',
                  averageErrorLabel: averageErrorBeats == null
                      ? 'No matches'
                      : '${averageErrorBeats.toStringAsFixed(2)} beat',
                  shiftLabel: result == null
                      ? 'Not run'
                      : '${shiftBeats! >= 0 ? '+' : ''}${shiftBeats.toStringAsFixed(2)} beat',
                );

                final tempo = _TempoStrip(
                  bpm: notifier.score.bpm,
                  enabled: !notifier.isBusy,
                  onTempoChanged: onTempoChanged,
                );

                final actionButtons = _ActionButtons(notifier: notifier);
                final tapButton = _TapButton(notifier: notifier);
                final compactActionRow = _CompactActionRow(notifier: notifier);

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (notifier.errorMessage != null) ...[
                        _InfoBanner(message: notifier.errorMessage!),
                        const SizedBox(height: 8),
                      ],
                      _CompactSummaryWrap(
                        phase: notifier.phase,
                        matchedLabel: result == null
                            ? 'Not run'
                            : '${result.matchedCount} / ${result.expectedCount}',
                        averageErrorLabel: averageErrorBeats == null
                            ? 'No matches'
                            : '${averageErrorBeats.toStringAsFixed(2)} beat',
                        shiftLabel: result == null
                            ? 'Not run'
                            : '${shiftBeats! >= 0 ? '+' : ''}${shiftBeats.toStringAsFixed(2)} beat',
                      ),
                      const SizedBox(height: 8),
                      tempo,
                      const SizedBox(height: 8),
                      compactActionRow,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (notifier.errorMessage != null) ...[
                      _InfoBanner(message: notifier.errorMessage!),
                      const SizedBox(height: 10),
                    ],
                    summary,
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: tempo),
                          const SizedBox(width: 12),
                          SizedBox(width: 280, child: actionButtons),
                          const SizedBox(width: 12),
                          SizedBox(width: 160, child: tapButton),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x18C62828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55C62828)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFC62828),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SummaryWrap extends StatelessWidget {
  const _SummaryWrap({
    required this.phase,
    required this.matchedLabel,
    required this.averageErrorLabel,
    required this.shiftLabel,
  });

  final RhythmTestPhase phase;
  final String matchedLabel;
  final String averageErrorLabel;
  final String shiftLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryTile(label: 'Phase', value: _phaseLabel(phase)),
        _SummaryTile(label: 'Matched', value: matchedLabel),
        _SummaryTile(label: 'Avg abs error', value: averageErrorLabel),
        _SummaryTile(label: 'Shift', value: shiftLabel),
      ],
    );
  }

  String _phaseLabel(RhythmTestPhase phase) {
    return switch (phase) {
      RhythmTestPhase.idle => 'Ready',
      RhythmTestPhase.countIn => 'Count-in',
      RhythmTestPhase.running => 'Running',
      RhythmTestPhase.finished => 'Result',
      RhythmTestPhase.cancelled => 'Stopped',
    };
  }
}

class _CompactSummaryWrap extends StatelessWidget {
  const _CompactSummaryWrap({
    required this.phase,
    required this.matchedLabel,
    required this.averageErrorLabel,
    required this.shiftLabel,
  });

  final RhythmTestPhase phase;
  final String matchedLabel;
  final String averageErrorLabel;
  final String shiftLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D6C4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Phase ${_phaseLabel(phase)}   Matched $matchedLabel',
              style: const TextStyle(
                color: Color(0xFF2B251C),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Avg $averageErrorLabel   Shift $shiftLabel',
              style: const TextStyle(
                color: Color(0xFF6E6254),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(RhythmTestPhase phase) {
    return switch (phase) {
      RhythmTestPhase.idle => 'Ready',
      RhythmTestPhase.countIn => 'Count-in',
      RhythmTestPhase.running => 'Running',
      RhythmTestPhase.finished => 'Result',
      RhythmTestPhase.cancelled => 'Stopped',
    };
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D6C4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF857764), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2B251C),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TempoStrip extends StatelessWidget {
  const _TempoStrip({
    required this.bpm,
    required this.enabled,
    required this.onTempoChanged,
  });

  final double bpm;
  final bool enabled;
  final ValueChanged<double> onTempoChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0D6C4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              child: Text(
                'BPM ${bpm.round()}',
                style: const TextStyle(
                  color: Color(0xFF2B251C),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Slider(
                value: bpm,
                min: 40,
                max: 240,
                divisions: 200,
                label: '${bpm.round()} BPM',
                onChanged: enabled ? onTempoChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.notifier});

  final RhythmTestNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('rhythm-test-start'),
            onPressed: notifier.canStart
                ? () => context.read<RhythmTestNotifier>().start()
                : null,
            icon: Icon(
              notifier.result == null
                  ? Icons.play_arrow_rounded
                  : Icons.replay_rounded,
            ),
            label: Text(notifier.result == null ? 'Start test' : 'Run again'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('rhythm-test-reset'),
            onPressed: notifier.isBusy
                ? () => context.read<RhythmTestNotifier>().stop()
                : notifier.result != null ||
                      notifier.phase == RhythmTestPhase.cancelled
                ? () => context.read<RhythmTestNotifier>().reset()
                : null,
            icon: Icon(
              notifier.isBusy ? Icons.stop_rounded : Icons.refresh_rounded,
            ),
            label: Text(notifier.isBusy ? 'Stop' : 'Reset'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactActionRow extends StatelessWidget {
  const _CompactActionRow({required this.notifier});

  final RhythmTestNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('rhythm-test-start'),
            onPressed: notifier.canStart
                ? () => context.read<RhythmTestNotifier>().start()
                : null,
            icon: Icon(
              notifier.result == null
                  ? Icons.play_arrow_rounded
                  : Icons.replay_rounded,
              size: 18,
            ),
            label: Text(notifier.result == null ? 'Start' : 'Again'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('rhythm-test-reset'),
            onPressed: notifier.isBusy
                ? () => context.read<RhythmTestNotifier>().stop()
                : notifier.result != null ||
                      notifier.phase == RhythmTestPhase.cancelled
                ? () => context.read<RhythmTestNotifier>().reset()
                : null,
            icon: Icon(
              notifier.isBusy ? Icons.stop_rounded : Icons.refresh_rounded,
              size: 18,
            ),
            label: Text(notifier.isBusy ? 'Stop' : 'Reset'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            key: const ValueKey('rhythm-test-tap'),
            onPressed:
                notifier.phase == RhythmTestPhase.countIn ||
                    notifier.phase == RhythmTestPhase.running
                ? () => context.read<RhythmTestNotifier>().recordTap()
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB44D2B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text('Tap'),
          ),
        ),
      ],
    );
  }
}

class _TapButton extends StatelessWidget {
  const _TapButton({required this.notifier});

  final RhythmTestNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const ValueKey('rhythm-test-tap'),
      onPressed:
          notifier.phase == RhythmTestPhase.countIn ||
              notifier.phase == RhythmTestPhase.running
          ? () => context.read<RhythmTestNotifier>().recordTap()
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFB44D2B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      child: const Text('Tap'),
    );
  }
}
