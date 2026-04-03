import '../models/portable_score_document.dart';

enum ScoreSeedKind { restore, blank, preset, saved, imported }

class ScoreSeedConfig {
  const ScoreSeedConfig.restore()
    : kind = ScoreSeedKind.restore,
      presetId = null,
      savedScoreId = null,
      document = null;

  const ScoreSeedConfig.blank()
    : kind = ScoreSeedKind.blank,
      presetId = null,
      savedScoreId = null,
      document = null;

  const ScoreSeedConfig.preset(this.presetId)
    : kind = ScoreSeedKind.preset,
      savedScoreId = null,
      document = null;

  const ScoreSeedConfig.saved(this.savedScoreId)
    : kind = ScoreSeedKind.saved,
      presetId = null,
      document = null;

  const ScoreSeedConfig.imported(this.document)
    : kind = ScoreSeedKind.imported,
      presetId = null,
      savedScoreId = null;

  final ScoreSeedKind kind;
  final String? presetId;
  final String? savedScoreId;
  final PortableScoreDocument? document;

  bool get isRestore => kind == ScoreSeedKind.restore;
  bool get isBlank => kind == ScoreSeedKind.blank;
  bool get isPreset => kind == ScoreSeedKind.preset;
  bool get isSaved => kind == ScoreSeedKind.saved;
  bool get isImported => kind == ScoreSeedKind.imported;
}
