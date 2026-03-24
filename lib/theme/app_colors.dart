import 'package:flutter/material.dart';

/// Semantic color palette for Tap Score.
///
/// All widget-level colors should reference these constants instead of
/// hard-coding hex values. This keeps the palette consistent and makes
/// a future dark-mode implementation straightforward.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Surface / Background
  // ---------------------------------------------------------------------------

  /// Lightest surface (e.g. score canvas).
  static const Color surface = Color(0xFFF8F6F0);

  /// Scaffold / page background.
  static const Color surfaceDim = Color(0xFFF5F3ED);

  /// Panels, toolbars, picker backgrounds.
  static const Color surfaceContainer = Color(0xFFF0EDE4);

  /// Cards, parameter strips, chips.
  static const Color surfaceContainerHigh = Color(0xFFFBF7EE);

  /// Score canvas.
  static const Color scoreBackground = Color(0xFFFFFBF0);

  // ---------------------------------------------------------------------------
  // Borders / Dividers
  // ---------------------------------------------------------------------------

  /// Container / card border.
  static const Color surfaceBorder = Color(0xFFE0D6C4);

  /// Picker item border (unselected).
  static const Color surfaceBorderDim = Color(0xFFDDDAD0);

  /// Divider line between sections.
  static const Color surfaceDivider = Color(0xFFE0DDD4);

  // ---------------------------------------------------------------------------
  // Text / Icon
  // ---------------------------------------------------------------------------

  /// Primary text (headings, labels).
  static const Color textPrimary = Color(0xFF333333);

  /// Secondary text / icons.
  static const Color textSecondary = Color(0xFF555555);

  /// Tertiary text (captions, parameter labels).
  static const Color textTertiary = Color(0xFF8A7D6A);

  /// Muted text (shortcut badges, minor labels).
  static const Color textMuted = Color(0xFF746A57);

  /// Dark brown text used in parameter values.
  static const Color textDark = Color(0xFF534838);

  /// Tempo label / medium dark text.
  static const Color textMedium = Color(0xFF444444);

  /// Score chip label.
  static const Color textChip = Color(0xFF4E473A);

  /// Very dark text (result card body).
  static const Color textBody = Color(0xFF2B251C);

  /// Subtle secondary (picker hint line, secondary accidental text).
  static const Color textHint = Color(0xFF888888);

  // ---------------------------------------------------------------------------
  // Accent
  // ---------------------------------------------------------------------------

  /// Blue accent — selected state, picker highlight.
  static const Color accentBlue = Color(0xFF1976D2);

  /// Amber — unsaved indicator, current-score badge, rhythm test brand.
  static const Color accentAmber = Color(0xFFD97706);

  /// Slider active track (playback tempo).
  static const Color sliderActive = Color(0xFF2196F3);

  /// Slider inactive track (playback tempo).
  static const Color sliderInactive = Color(0xFFE0E0E0);

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Success / correct.
  static const Color statusSuccess = Color(0xFF1E8E5A);

  /// Warning / loose timing.
  static const Color statusWarning = Color(0xFFEF6C00);

  /// Error / failure.
  static const Color statusError = Color(0xFFC62828);

  // ---------------------------------------------------------------------------
  // Toolbar tool colors (DurationSelector)
  // ---------------------------------------------------------------------------

  static const Color toolRest = Color(0xFF9C27B0);
  static const Color toolDuration = Color(0xFF2196F3);
  static const Color toolDot = Color(0xFFFF9800);
  static const Color toolSlur = Color(0xFF5E35B1);
  static const Color toolTriplet = Color(0xFF00897B);
  static const Color toolDelete = Color(0xFFF44336);

  // ---------------------------------------------------------------------------
  // Duration selector shortcut badge
  // ---------------------------------------------------------------------------

  static const Color shortcutBadgeBackground = Color(0xFFE8E4D8);

  // ---------------------------------------------------------------------------
  // Rhythm Test brand
  // ---------------------------------------------------------------------------

  static const Color rhythmTestGradientStart = Color(0xFFFFC145);
  static const Color rhythmTestGradientEnd = Color(0xFFF59E0B);
  static const Color rhythmTestBorder = Color(0xFFE0A64B);
  static const Color rhythmTestText = Color(0xFF4A3411);

  // ---------------------------------------------------------------------------
  // Rhythm Test panel
  // ---------------------------------------------------------------------------

  /// Slider track (warm neutral).
  static const Color panelSliderActive = Color(0xFF7A705F);
  static const Color panelSliderInactive = Color(0xFFD8D0C1);

  /// Primary action background.
  static const Color panelActionBackground = Color(0xFF2F261C);
  static const Color panelActionDisabled = Color(0xFFBFB6A7);

  /// Adjust button disabled.
  static const Color panelAdjustDisabled = Color(0xFFB7AE9F);

  // ---------------------------------------------------------------------------
  // Rhythm Test result card
  // ---------------------------------------------------------------------------

  static const Color resultCardBackground = Color(0xEEF8F5EE);
  static const Color resultCardBorder = Color(0xFFD6CCBA);
  static const Color resultMetricBorder = Color(0xFFDCCFB9);

  // ---------------------------------------------------------------------------
  // Rhythm Test timeline
  // ---------------------------------------------------------------------------

  static const Color timelineBackground = Color(0xFFFFFCF5);
  static const Color timelineBorder = Color(0xFFE3DDD0);
  static const Color timelineTrack = Color(0xFFD7D0C0);
  static const Color timelineMeasure = Color(0xFFD4CCBC);
  static const Color timelineBeat = Color(0xFFF0E7D8);
  static const Color timelineLabel = Color(0xFF6E6254);
  static const Color timelineErrorBackground = Color(0xEEFFFDF7);
  static const Color timelineMatchedScore = Color(0xFF1565C0);
  static const Color timelineUnmatchedScore = Color(0xFFC62828);
  static const Color timelineMatchedTap = Color(0xFF00897B);
  static const Color timelineUnmatchedTap = Color(0xFF5D4037);
  static const Color timelineMatchGood = Color(0xFF2E7D32);
  static const Color timelineMatchWarn = Color(0xFFF57C00);

  // ---------------------------------------------------------------------------
  // Rhythm Test workspace exit button
  // ---------------------------------------------------------------------------

  static const Color exitButtonBackground = Color(0xD9FBF7EE);
  static const Color exitButtonIcon = Color(0xFF5B5142);

  // ---------------------------------------------------------------------------
  // Piano keyboard
  // ---------------------------------------------------------------------------

  static const Color keyboardBackground = Color(0xFF1A1A2E);
  static const Color keyboardControlPanel = Color(0xFF22223B);
  static const Color keyboardControlBorder = Color(0xFF3C3C59);
  static const Color keyboardControlText = Color(0xFFD9D9E8);
  static const Color keyboardArrowButton = Color(0xFF30304B);
  static const Color keyboardToggleTrack = Color(0xFF161629);
  static const Color keyboardToggleBorder = Color(0xFF404060);
  static const Color keyboardToggleKeySig = Color(0xFF486284);
  static const Color keyboardToggleChromatic = Color(0xFF9A4F2E);

  /// Shortcut badge colors (on dark keyboard).
  static const Color keyBadgeDefault = Color(0xFF2F4156);
  static const Color keyBadgeShift = Color(0xFF4D6B8A);
  static const Color keyBadgeDisabled = Color(0xFF9A9388);

  /// White key disabled label color.
  static const Color whiteKeyDisabledLabel = Color(0xFF9D9B95);
  static const Color whiteKeyBorderEnabled = Color(0xFFBBB8B0);
  static const Color whiteKeyBorderDisabled = Color(0xFFC7C3B8);

  // ---------------------------------------------------------------------------
  // Play button
  // ---------------------------------------------------------------------------

  static const Color playGradientStart = Color(0xFF4CAF50);
  static const Color playGradientEnd = Color(0xFF388E3C);
  static const Color stopGradientStart = Color(0xFFF44336);
  static const Color stopGradientEnd = Color(0xFFD32F2F);
  static const Color playDisabledStart = Color(0xFFBDBDBD);
  static const Color playDisabledEnd = Color(0xFF9E9E9E);
}
