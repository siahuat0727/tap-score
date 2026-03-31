class EditorLaunchConfig {
  const EditorLaunchConfig.blank() : presetId = null;

  const EditorLaunchConfig.preset(this.presetId);

  final String? presetId;

  bool get isBlank => presetId == null;
  bool get isPreset => presetId != null;

  String get routeLocation {
    if (presetId case final presetId?) {
      return '/editor?preset=${Uri.encodeQueryComponent(presetId)}';
    }
    return '/editor?mode=blank';
  }
}
