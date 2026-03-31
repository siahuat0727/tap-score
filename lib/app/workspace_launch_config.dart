import 'score_seed_config.dart';

enum WorkspaceMode { compose, rhythmTest }

class WorkspaceLaunchConfig {
  const WorkspaceLaunchConfig({
    required this.seedConfig,
    required this.initialMode,
  });

  const WorkspaceLaunchConfig.blank()
    : seedConfig = const ScoreSeedConfig.blank(),
      initialMode = WorkspaceMode.compose;

  WorkspaceLaunchConfig.preset(
    String presetId, {
    required WorkspaceMode initialMode,
  }) : this(
         seedConfig: ScoreSeedConfig.preset(presetId),
         initialMode: initialMode,
       );

  final ScoreSeedConfig seedConfig;
  final WorkspaceMode initialMode;

  String? get presetId => seedConfig.presetId;

  bool get isBlank => seedConfig.isBlank;

  String get routeLocation =>
      routeLocationFor(mode: initialMode, presetId: presetId);

  static String routeLocationFor({
    required WorkspaceMode mode,
    String? presetId,
  }) {
    if (presetId case final presetId? when presetId.isNotEmpty) {
      final encodedPresetId = Uri.encodeQueryComponent(presetId);
      return switch (mode) {
        WorkspaceMode.compose => '/editor?preset=$encodedPresetId',
        WorkspaceMode.rhythmTest => '/practice?preset=$encodedPresetId',
      };
    }

    return '/editor?mode=blank';
  }
}
