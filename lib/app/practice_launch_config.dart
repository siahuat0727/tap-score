import 'score_seed_config.dart';

class PracticeLaunchConfig {
  const PracticeLaunchConfig(this.presetId) : assert(presetId != '');

  final String presetId;

  ScoreSeedConfig get seedConfig => ScoreSeedConfig.preset(presetId);

  String get routeLocation =>
      '/practice?preset=${Uri.encodeQueryComponent(presetId)}';
}
