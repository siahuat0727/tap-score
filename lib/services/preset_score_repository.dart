import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/portable_score_document.dart';
import '../models/score_library.dart';

class PresetScoreException implements Exception {
  const PresetScoreException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    return cause == null
        ? 'PresetScoreException: $message'
        : 'PresetScoreException: $message ($cause)';
  }
}

abstract class PresetScoreRepository {
  Future<List<PresetScoreEntry>> loadPresets();
}

class AssetPresetScoreRepository implements PresetScoreRepository {
  AssetPresetScoreRepository({
    AssetBundle? assetBundle,
    Future<AssetManifest> Function(AssetBundle bundle)? assetManifestLoader,
    this.presetsDirectory = 'assets/presets/',
  }) : _assetBundle = assetBundle ?? rootBundle,
       _assetManifestLoader =
           assetManifestLoader ?? AssetManifest.loadFromAssetBundle;

  final AssetBundle _assetBundle;
  final Future<AssetManifest> Function(AssetBundle bundle) _assetManifestLoader;
  final String presetsDirectory;

  @override
  Future<List<PresetScoreEntry>> loadPresets() async {
    late final AssetManifest assetManifest;
    try {
      assetManifest = await _assetManifestLoader(_assetBundle);
    } catch (error) {
      throw PresetScoreException(
        'Failed to load preset score manifest.',
        cause: error,
      );
    }

    final presetAssetPaths = assetManifest.listAssets()
      ..sort()
      ..retainWhere(
        (assetPath) =>
            assetPath.startsWith(presetsDirectory) &&
            assetPath != presetsDirectory &&
            assetPath.endsWith('.json'),
      );

    final presets = <PresetScoreEntry>[];
    final seenIds = <String>{};

    for (final assetPath in presetAssetPaths) {
      final id = _derivePresetId(assetPath);
      if (!seenIds.add(id)) {
        throw PresetScoreException('Duplicate preset id "$id" detected.');
      }

      try {
        final rawDocument = await _assetBundle.loadString(assetPath);
        final decodedDocument = jsonDecode(rawDocument);
        if (decodedDocument is! Map<String, dynamic>) {
          throw PresetScoreException(
            'Preset "$id" document must be a JSON object.',
          );
        }

        final document = PortableScoreDocument.fromJson(decodedDocument);
        presets.add(
          PresetScoreEntry(
            id: id,
            name: document.name,
            assetPath: assetPath,
            score: document.score,
          ),
        );
      } on PresetScoreException {
        rethrow;
      } catch (error) {
        throw PresetScoreException(
          'Failed to load preset "$id".',
          cause: error,
        );
      }
    }

    return List.unmodifiable(presets);
  }

  String _derivePresetId(String assetPath) {
    if (!assetPath.startsWith(presetsDirectory) ||
        !assetPath.endsWith('.json')) {
      throw PresetScoreException(
        'Preset asset path "$assetPath" is outside $presetsDirectory or does not end with .json.',
      );
    }

    final relativePath = assetPath.substring(presetsDirectory.length);
    final id = relativePath.substring(0, relativePath.length - '.json'.length);
    if (id.isEmpty) {
      throw PresetScoreException(
        'Preset asset path "$assetPath" does not produce a valid id.',
      );
    }
    return id;
  }
}
