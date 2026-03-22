import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/score_library.dart';

class ScoreLibraryStorageException implements Exception {
  const ScoreLibraryStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'ScoreLibraryStorageException: $message'
        : 'ScoreLibraryStorageException: $message ($cause)';
  }
}

abstract class ScoreLibraryRepository {
  Future<ScoreLibrarySnapshot?> loadSnapshot();

  Future<void> saveSnapshot(ScoreLibrarySnapshot snapshot);
}

class SharedPreferencesScoreLibraryRepository
    implements ScoreLibraryRepository {
  static const String _snapshotKey = 'tap_score.score_library.v1';

  SharedPreferencesScoreLibraryRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  SharedPreferences? _preferences;

  Future<SharedPreferences> _instance() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<ScoreLibrarySnapshot?> loadSnapshot() async {
    final preferences = await _instance();
    final raw = preferences.getString(_snapshotKey);
    if (raw == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const ScoreLibraryStorageException(
          'Stored score library payload is not a JSON object.',
        );
      }
      return ScoreLibrarySnapshot.fromJson(decoded);
    } on ScoreLibraryStorageException {
      rethrow;
    } catch (error) {
      throw ScoreLibraryStorageException(
        'Failed to parse the local score library.',
        cause: error,
      );
    }
  }

  @override
  Future<void> saveSnapshot(ScoreLibrarySnapshot snapshot) async {
    final preferences = await _instance();
    final ok = await preferences.setString(
      _snapshotKey,
      jsonEncode(snapshot.toJson()),
    );
    if (!ok) {
      throw const ScoreLibraryStorageException(
        'Failed to write the local score library.',
      );
    }
  }
}
