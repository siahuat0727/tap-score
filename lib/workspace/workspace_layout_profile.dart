import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/piano_keyboard.dart';

class WorkspaceLayoutProfile {
  const WorkspaceLayoutProfile({
    required this.isPhone,
    required this.topBarUsesTwoRows,
    required this.topBarActionButtonsIconOnly,
    required this.topBarModeSwitchMaxWidth,
    required this.composeMetrics,
    required this.rhythmPanelCompact,
    required this.rhythmPanelSingleColumn,
    required this.rhythmControlBarBaseHeight,
    required this.rhythmControlBarErrorExtraHeight,
    required this.rhythmResultOverlayAlignment,
    required this.rhythmResultOverlayPadding,
  });

  final bool isPhone;
  final bool topBarUsesTwoRows;
  final bool topBarActionButtonsIconOnly;
  final double topBarModeSwitchMaxWidth;
  final WorkspaceComposeMetrics composeMetrics;
  final bool rhythmPanelCompact;
  final bool rhythmPanelSingleColumn;
  final double rhythmControlBarBaseHeight;
  final double rhythmControlBarErrorExtraHeight;
  final Alignment rhythmResultOverlayAlignment;
  final EdgeInsets rhythmResultOverlayPadding;

  static WorkspaceLayoutProfile fromSize(Size size) {
    final width = math.max(size.width, 0);
    final height = math.max(size.height, 0);
    final isPhone = width < 700 || height < 640;
    final isCompact = isPhone || width < 1040 || height < 740;

    if (isPhone) {
      return WorkspaceLayoutProfile(
        isPhone: true,
        topBarUsesTwoRows: true,
        topBarActionButtonsIconOnly: true,
        topBarModeSwitchMaxWidth: 320,
        composeMetrics: WorkspaceComposeMetrics.phone,
        rhythmPanelCompact: true,
        rhythmPanelSingleColumn: true,
        rhythmControlBarBaseHeight: 292,
        rhythmControlBarErrorExtraHeight: 84,
        rhythmResultOverlayAlignment: const Alignment(0, 0.66),
        rhythmResultOverlayPadding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
      );
    }

    if (isCompact) {
      return WorkspaceLayoutProfile(
        isPhone: false,
        topBarUsesTwoRows: false,
        topBarActionButtonsIconOnly: false,
        topBarModeSwitchMaxWidth: 300,
        composeMetrics: WorkspaceComposeMetrics.compact,
        rhythmPanelCompact: false,
        rhythmPanelSingleColumn: false,
        rhythmControlBarBaseHeight: 208,
        rhythmControlBarErrorExtraHeight: 84,
        rhythmResultOverlayAlignment: const Alignment(0, 0.7),
        rhythmResultOverlayPadding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      );
    }

    return WorkspaceLayoutProfile(
      isPhone: false,
      topBarUsesTwoRows: false,
      topBarActionButtonsIconOnly: false,
      topBarModeSwitchMaxWidth: 340,
      composeMetrics: WorkspaceComposeMetrics.regular,
      rhythmPanelCompact: false,
      rhythmPanelSingleColumn: false,
      rhythmControlBarBaseHeight: 176,
      rhythmControlBarErrorExtraHeight: 84,
      rhythmResultOverlayAlignment: const Alignment(0, 0.72),
      rhythmResultOverlayPadding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
    );
  }
}

class WorkspaceComposeMetrics {
  const WorkspaceComposeMetrics({
    required this.preferredScoreMinHeight,
    required this.minimumVisibleScoreHeight,
    required this.preferredToolbarHeight,
    required this.minimumComposeDockViewportHeight,
    required this.toolbarPadding,
    required this.toolbarSectionPadding,
    required this.toolbarSectionGap,
    required this.infoChipSpacing,
    required this.infoChipRunSpacing,
    required this.keyboardLayout,
    required this.toolbarUsesCompactHeader,
  });

  static const regular = WorkspaceComposeMetrics(
    preferredScoreMinHeight: 280,
    minimumVisibleScoreHeight: 168,
    preferredToolbarHeight: 132,
    minimumComposeDockViewportHeight: 132,
    toolbarPadding: EdgeInsets.fromLTRB(12, 10, 12, 8),
    toolbarSectionPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    toolbarSectionGap: 10,
    infoChipSpacing: 10,
    infoChipRunSpacing: 8,
    keyboardLayout: PianoKeyboardLayout.regular,
    toolbarUsesCompactHeader: false,
  );

  static const compact = WorkspaceComposeMetrics(
    preferredScoreMinHeight: 264,
    minimumVisibleScoreHeight: 148,
    preferredToolbarHeight: 108,
    minimumComposeDockViewportHeight: 108,
    toolbarPadding: EdgeInsets.fromLTRB(10, 8, 10, 6),
    toolbarSectionPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    toolbarSectionGap: 8,
    infoChipSpacing: 8,
    infoChipRunSpacing: 6,
    keyboardLayout: PianoKeyboardLayout.compact,
    toolbarUsesCompactHeader: true,
  );

  static const phone = WorkspaceComposeMetrics(
    preferredScoreMinHeight: 264,
    minimumVisibleScoreHeight: 148,
    preferredToolbarHeight: 108,
    minimumComposeDockViewportHeight: 108,
    toolbarPadding: EdgeInsets.fromLTRB(10, 8, 10, 6),
    toolbarSectionPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    toolbarSectionGap: 8,
    infoChipSpacing: 8,
    infoChipRunSpacing: 6,
    keyboardLayout: PianoKeyboardLayout.compact,
    toolbarUsesCompactHeader: true,
  );

  final double preferredScoreMinHeight;
  final double minimumVisibleScoreHeight;
  final double preferredToolbarHeight;
  final double minimumComposeDockViewportHeight;
  final EdgeInsets toolbarPadding;
  final EdgeInsets toolbarSectionPadding;
  final double toolbarSectionGap;
  final double infoChipSpacing;
  final double infoChipRunSpacing;
  final PianoKeyboardLayout keyboardLayout;
  final bool toolbarUsesCompactHeader;

  double get preferredComposeDockHeight =>
      preferredToolbarHeight + keyboardLayout.height;

  WorkspaceComposeBodyLayout resolveBodyLayout(double availableHeight) {
    final contentHeight = math.max(availableHeight, 0.0);
    if (contentHeight <= 0) {
      return const WorkspaceComposeBodyLayout(
        scoreHeight: 0,
        composeDockHeight: 0,
      );
    }

    final dividerHeight = contentHeight > 1 ? 1.0 : 0.0;
    final minDockViewportHeight = math.min(
      minimumComposeDockViewportHeight,
      math.max(contentHeight - dividerHeight, 0.0),
    );
    final maxScoreHeight = math.max(
      contentHeight - minDockViewportHeight - dividerHeight,
      0.0,
    );
    final minScoreHeight = math.min(minimumVisibleScoreHeight, maxScoreHeight);
    final preferredScoreHeight = math.max(
      preferredScoreMinHeight,
      contentHeight - preferredComposeDockHeight - dividerHeight,
    );
    final scoreHeight = preferredScoreHeight.clamp(
      minScoreHeight,
      maxScoreHeight,
    );
    final composeDockHeight = math.max(
      contentHeight - scoreHeight - dividerHeight,
      0.0,
    );

    return WorkspaceComposeBodyLayout(
      scoreHeight: scoreHeight,
      composeDockHeight: composeDockHeight,
    );
  }
}

class WorkspaceComposeBodyLayout {
  const WorkspaceComposeBodyLayout({
    required this.scoreHeight,
    required this.composeDockHeight,
  });

  final double scoreHeight;
  final double composeDockHeight;
}
