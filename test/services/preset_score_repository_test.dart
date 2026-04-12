import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_score/services/preset_score_repository.dart';

void main() {
  test('asset preset repository loads ordered preset entries', () async {
    final repository = AssetPresetScoreRepository(
      assetBundle: _FakeAssetBundle({
        'assets/presets/z_triplet.json': '''
{
  "version": 1,
  "name": "Triplet",
  "score": {
    "notes": [],
    "beatsPerMeasure": 3,
    "beatUnit": 4,
    "bpm": 90,
    "clef": "treble",
    "keySignature": "gMajor"
  }
}
''',
        'assets/presets/a_warmup.json': '''
{
  "version": 1,
  "name": "Warmup",
  "score": {
    "notes": [],
    "beatsPerMeasure": 4,
    "beatUnit": 4,
    "bpm": 120,
    "clef": "treble",
    "keySignature": "cMajor"
  }
}
''',
        'assets/presets/readme.txt': 'ignore me',
      }),
      assetManifestLoader: (_) async => const _FakeAssetManifest([
        'assets/presets/z_triplet.json',
        'assets/presets/readme.txt',
        'assets/presets/a_warmup.json',
      ]),
    );

    final presets = await repository.loadPresets();

    expect(presets.map((entry) => entry.id), ['a_warmup', 'z_triplet']);
    expect(presets.first.name, 'Warmup');
    expect(presets.last.score.bpm, 90);
  });

  test('asset preset repository rejects malformed preset documents', () async {
    final repository = AssetPresetScoreRepository(
      assetBundle: _FakeAssetBundle({
        'assets/presets/broken.json': '{"version": 1, "name": "Broken"}',
      }),
      assetManifestLoader: (_) async =>
          const _FakeAssetManifest(['assets/presets/broken.json']),
    );

    await expectLater(
      repository.loadPresets(),
      throwsA(isA<PresetScoreException>()),
    );
  });

  test('asset preset repository rejects duplicate derived ids', () async {
    final repository = AssetPresetScoreRepository(
      assetBundle: _FakeAssetBundle({
        'assets/presets/dup.json': '''
{
  "version": 1,
  "name": "Duplicate",
  "score": {
    "notes": [],
    "beatsPerMeasure": 4,
    "beatUnit": 4,
    "bpm": 120,
    "clef": "treble",
    "keySignature": "cMajor"
  }
}
''',
      }),
      assetManifestLoader: (_) async => const _FakeAssetManifest([
        'assets/presets/dup.json',
        'assets/presets/dup.json',
      ]),
    );

    await expectLater(
      repository.loadPresets(),
      throwsA(isA<PresetScoreException>()),
    );
  });
}

class _FakeAssetBundle implements AssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = _assets[key];
    if (value == null) {
      throw Exception('Missing asset: $key');
    }
    return value;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAssetManifest implements AssetManifest {
  const _FakeAssetManifest(this._assets);

  final List<String> _assets;

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;

  @override
  List<String> listAssets() => List<String>.from(_assets);
}
