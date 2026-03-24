import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/rhythm_test_notifier.dart';
import '../theme/app_colors.dart';
import 'rhythm_test_panel.dart';
import 'score_view_widget.dart';

class RhythmTestWorkspace extends StatelessWidget {
  const RhythmTestWorkspace({
    required this.onTempoChanged,
    required this.onRendererKeyDown,
    required this.onExit,
    super.key,
  });

  final ValueChanged<double> onTempoChanged;
  final bool Function(String? key, String? code)? onRendererKeyDown;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Consumer<RhythmTestNotifier>(
      builder: (context, notifier, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final baseControlBarHeight = constraints.maxWidth < 700
                ? 208.0
                : 176.0;
            final controlBarHeight = notifier.errorMessage == null
                ? baseControlBarHeight
                : baseControlBarHeight + 84;

            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ScoreViewWidget(
                          interactive: false,
                          onRendererKeyDown: onRendererKeyDown,
                          rhythmOverlay: notifier.overlayRenderData,
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: SafeArea(
                          bottom: false,
                          child: Tooltip(
                            message: 'Exit Rhythm Test',
                            child: Material(
                              key: const ValueKey('exit-rhythm-test-button'),
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: onExit,
                                child: Ink(
                                  width: 46,
                                  height: 46,
                                  decoration: const BoxDecoration(
                                    color: AppColors.exitButtonBackground,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x22000000),
                                        blurRadius: 16,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.exitButtonIcon,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: const Alignment(0, 0.72),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                32,
                                20,
                                28,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: notifier.showCenteredResult
                                    ? const _RhythmTestResultCard(
                                        key: ValueKey(
                                          'rhythm-test-result-card',
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.surfaceDivider),
                SizedBox(
                  height: controlBarHeight,
                  child: RhythmTestPanel(onTempoChanged: onTempoChanged),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RhythmTestResultCard extends StatelessWidget {
  const _RhythmTestResultCard({super.key});

  static const Color _successColor = AppColors.statusSuccess;
  static const Color _warningColor = AppColors.statusWarning;
  static const Color _failureColor = AppColors.statusError;
  static const Color _textColor = AppColors.textBody;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RhythmTestNotifier>();
    if (notifier.isScoringResult) {
      return _ResultCardShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 14),
            Text(
              'Calculating result…',
              style: TextStyle(
                color: _textColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    if (notifier.scoringErrorMessage != null) {
      return _ResultCardShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scoring Error',
              style: TextStyle(
                color: _failureColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              notifier.scoringErrorMessage!,
              style: const TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (notifier.result == null) {
      return const SizedBox.shrink();
    }

    final mistakesColor = notifier.resultErrorCount == 0
        ? _successColor
        : _failureColor;
    final largeOffsetsColor = notifier.resultLargeErrorCount == 0
        ? _successColor
        : _failureColor;
    final statusColor = switch (notifier.resultStatusLabel) {
      'Perfect' => _successColor,
      'Clean, but loose' => _warningColor,
      _ => _failureColor,
    };

    return _ResultCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  notifier.resultStatusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  notifier.resultParameterHint,
                  key: const ValueKey('rhythm-test-result-params'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PrimaryMetric(
                  key: const ValueKey('rhythm-test-mistakes'),
                  label: 'Mistakes',
                  value: notifier.resultErrorCountLabel,
                  valueColor: mistakesColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PrimaryMetric(
                  key: const ValueKey('rhythm-test-large-offsets'),
                  label: 'Large Offsets',
                  value: notifier.resultLargeErrorCountLabel,
                  valueColor: largeOffsetsColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SecondaryMetric(
                  label: 'Avg abs error',
                  value: notifier.resultAverageErrorBeats == null
                      ? 'No matches'
                      : '${notifier.resultAverageErrorBeats!.toStringAsFixed(2)} beat',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SecondaryMetric(
                  label: 'Max abs error',
                  value: notifier.resultMaxErrorBeats == null
                      ? 'No matches'
                      : '${notifier.resultMaxErrorBeats!.toStringAsFixed(2)} beat',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultCardShell extends StatelessWidget {
  const _ResultCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.resultCardBackground,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.resultCardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
          child: child,
        ),
      ),
    );
  }
}

class _PrimaryMetric extends StatelessWidget {
  const _PrimaryMetric({
    required super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(118),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.resultMetricBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: valueColor,
                fontSize: 46,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryMetric extends StatelessWidget {
  const _SecondaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x73FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.resultMetricBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _RhythmTestResultCard._textColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
