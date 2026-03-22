import 'score.dart';

class PresetScoreEntry {
  const PresetScoreEntry({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.score,
  });

  final String id;
  final String name;
  final String assetPath;
  final Score score;
}

class SavedScoreEntry {
  const SavedScoreEntry({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.score,
  });

  final String id;
  final String name;
  final DateTime updatedAt;
  final Score score;

  SavedScoreEntry copyWith({
    String? id,
    String? name,
    DateTime? updatedAt,
    Score? score,
  }) {
    return SavedScoreEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'updatedAt': updatedAt.toIso8601String(),
      'score': score.toJson(),
    };
  }

  factory SavedScoreEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw ArgumentError.value(json['id'], 'id', 'Expected a non-empty id');
    }

    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw ArgumentError.value(
        json['name'],
        'name',
        'Expected a non-empty name',
      );
    }

    final updatedAtRaw = json['updatedAt'];
    if (updatedAtRaw is! String) {
      throw ArgumentError.value(
        json['updatedAt'],
        'updatedAt',
        'Expected an ISO8601 string',
      );
    }
    final updatedAt = DateTime.tryParse(updatedAtRaw);
    if (updatedAt == null) {
      throw ArgumentError.value(
        json['updatedAt'],
        'updatedAt',
        'Expected a valid ISO8601 string',
      );
    }

    final scoreJson = json['score'];
    if (scoreJson is! Map<String, dynamic>) {
      throw ArgumentError.value(
        json['score'],
        'score',
        'Expected a score object',
      );
    }

    return SavedScoreEntry(
      id: id,
      name: name.trim(),
      updatedAt: updatedAt,
      score: Score.fromJson(scoreJson),
    );
  }
}

class ScoreLibrarySnapshot {
  const ScoreLibrarySnapshot({
    required this.draft,
    required this.savedScores,
    this.activeScoreId,
  });

  final Score draft;
  final List<SavedScoreEntry> savedScores;
  final String? activeScoreId;

  static ScoreLibrarySnapshot empty() {
    return ScoreLibrarySnapshot(draft: Score(), savedScores: const []);
  }

  ScoreLibrarySnapshot copyWith({
    Score? draft,
    List<SavedScoreEntry>? savedScores,
    String? Function()? activeScoreId,
  }) {
    return ScoreLibrarySnapshot(
      draft: draft ?? this.draft,
      savedScores: savedScores ?? this.savedScores,
      activeScoreId: activeScoreId != null
          ? activeScoreId()
          : this.activeScoreId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'draft': draft.toJson(),
      'savedScores': savedScores.map((entry) => entry.toJson()).toList(),
      'activeScoreId': activeScoreId,
    };
  }

  factory ScoreLibrarySnapshot.fromJson(Map<String, dynamic> json) {
    final draftJson = json['draft'];
    if (draftJson is! Map<String, dynamic>) {
      throw ArgumentError.value(
        json['draft'],
        'draft',
        'Expected a score object',
      );
    }

    final savedScoresJson = json['savedScores'];
    if (savedScoresJson is! List) {
      throw ArgumentError.value(
        json['savedScores'],
        'savedScores',
        'Expected a list of saved scores',
      );
    }

    final activeScoreId = json['activeScoreId'];
    if (activeScoreId != null && activeScoreId is! String) {
      throw ArgumentError.value(
        json['activeScoreId'],
        'activeScoreId',
        'Expected a string or null',
      );
    }

    return ScoreLibrarySnapshot(
      draft: Score.fromJson(draftJson),
      savedScores: savedScoresJson
          .map((entry) {
            if (entry is! Map<String, dynamic>) {
              throw ArgumentError.value(
                entry,
                'savedScores',
                'Expected a saved score object',
              );
            }
            return SavedScoreEntry.fromJson(entry);
          })
          .toList(growable: false),
      activeScoreId: activeScoreId,
    );
  }
}
