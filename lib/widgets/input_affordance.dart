import 'package:flutter/material.dart';

enum InputAffordanceProfile {
  desktopKeyboard,
  touchFirst;

  bool get showsKeyboardAffordances =>
      this == InputAffordanceProfile.desktopKeyboard;

  String get composeEmptyStateGuidance => switch (this) {
    InputAffordanceProfile.desktopKeyboard =>
      'Tap the piano or press A/S/D... to enter notes. Space plays.',
    InputAffordanceProfile.touchFirst =>
      'Tap the piano to enter notes. Press Play to listen back.',
  };
}

InputAffordanceProfile resolveInputAffordanceProfile(
  BuildContext context, {
  required bool compact,
}) {
  return inputAffordanceProfileForPlatform(
    Theme.of(context).platform,
    compact: compact,
  );
}

InputAffordanceProfile inputAffordanceProfileForPlatform(
  TargetPlatform platform, {
  required bool compact,
}) {
  if (compact) {
    return InputAffordanceProfile.touchFirst;
  }

  return switch (platform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => InputAffordanceProfile.desktopKeyboard,
    TargetPlatform.iOS ||
    TargetPlatform.android ||
    TargetPlatform.fuchsia => InputAffordanceProfile.touchFirst,
  };
}
