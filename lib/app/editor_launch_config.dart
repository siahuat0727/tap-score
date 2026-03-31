import 'score_seed_config.dart';

class EditorLaunchConfig {
  const EditorLaunchConfig.blank()
    : _seedConfig = const ScoreSeedConfig.blank();

  EditorLaunchConfig.preset(String presetId)
    : _seedConfig = ScoreSeedConfig.preset(presetId);

  final ScoreSeedConfig _seedConfig;

  ScoreSeedConfig get seedConfig => _seedConfig;

  String? get presetId => _seedConfig.presetId;

  bool get isBlank => _seedConfig.isBlank;
  bool get isPreset => _seedConfig.isPreset;

  String get routeLocation {
    if (presetId case final presetId?) {
      return '/editor?preset=${Uri.encodeQueryComponent(presetId)}';
    }
    return '/editor?mode=blank';
  }
}
