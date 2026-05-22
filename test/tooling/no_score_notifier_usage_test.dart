import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScoreNotifier is not used by app or tests', () {
    final roots = [Directory('lib'), Directory('test')];
    final offenders = <String>[];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        if (entity.path == 'test/tooling/no_score_notifier_usage_test.dart') {
          continue;
        }
        final contents = entity.readAsStringSync();
        if (contents.contains('ScoreNotifier') ||
            contents.contains('score_notifier.dart')) {
          offenders.add(entity.path);
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
