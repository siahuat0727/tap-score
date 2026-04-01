import '../models/portable_score_document.dart';

enum ScoreSeedKind { restore, blank, preset, imported }

class ScoreSeedConfig {
  const ScoreSeedConfig.restore()
    : kind = ScoreSeedKind.restore,
      presetId = null,
      document = null;

  const ScoreSeedConfig.blank()
    : kind = ScoreSeedKind.blank,
      presetId = null,
      document = null;

  const ScoreSeedConfig.preset(this.presetId)
    : kind = ScoreSeedKind.preset,
      document = null;

  const ScoreSeedConfig.imported(this.document)
    : kind = ScoreSeedKind.imported,
      presetId = null;

  final ScoreSeedKind kind;
  final String? presetId;
  final PortableScoreDocument? document;

  bool get isRestore => kind == ScoreSeedKind.restore;
  bool get isBlank => kind == ScoreSeedKind.blank;
  bool get isPreset => kind == ScoreSeedKind.preset;
  bool get isImported => kind == ScoreSeedKind.imported;
}
