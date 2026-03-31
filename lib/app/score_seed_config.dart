class ScoreSeedConfig {
  const ScoreSeedConfig.blank() : presetId = null;

  const ScoreSeedConfig.preset(this.presetId);

  final String? presetId;

  bool get isBlank => presetId == null;
  bool get isPreset => presetId != null;
}
