import 'package:flutter/material.dart';

import '../models/key_signature.dart';
import '../models/score.dart';
import '../state/score_notifier.dart';
import '../theme/app_colors.dart';

/// Shows a bottom-sheet picker for selecting a time signature.
void showTimeSigPicker(BuildContext context, ScoreNotifier notifier) {
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
              children: commonTimeSignatures.map((sig) {
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
                          ? AppColors.accentBlue
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.accentBlue
                            : AppColors.surfaceBorderDim,
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
                                : AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          height: 1.5,
                          width: 28,
                          color: isCurrent
                              ? Colors.white70
                              : AppColors.textHint,
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
                                : AppColors.textPrimary,
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

/// Shows a bottom-sheet picker for selecting a key signature.
void showKeySigPicker(BuildContext context, ScoreNotifier notifier) {
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
                          ? AppColors.accentBlue
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.accentBlue
                            : AppColors.surfaceBorderDim,
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
                                : AppColors.textPrimary,
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
                                : AppColors.textHint,
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
