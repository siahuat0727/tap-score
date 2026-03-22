import 'score.dart';

class PortableScoreDocument {
  const PortableScoreDocument({
    required this.version,
    required this.name,
    required this.score,
  });

  static const int currentVersion = 1;

  final int version;
  final String name;
  final Score score;

  Map<String, dynamic> toJson() {
    return {'version': version, 'name': name, 'score': score.toJson()};
  }

  factory PortableScoreDocument.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int) {
      throw ArgumentError.value(
        json['version'],
        'version',
        'Expected an integer version',
      );
    }
    if (version != currentVersion) {
      throw ArgumentError.value(
        version,
        'version',
        'Unsupported score document version',
      );
    }

    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw ArgumentError.value(
        json['name'],
        'name',
        'Expected a non-empty document name',
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

    return PortableScoreDocument(
      version: version,
      name: name.trim(),
      score: Score.fromJson(scoreJson),
    );
  }
}
