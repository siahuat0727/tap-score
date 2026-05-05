import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int _indexOfOrFail(String source, String expected) {
  final index = source.indexOf(expected);
  expect(index, isNonNegative, reason: 'Missing: $expected');
  return index;
}

void main() {
  test('Cloudflare build reuses the pinned Flutter SDK setup', () {
    final flutterSdkScript = File('tool/flutter_sdk.sh');
    expect(flutterSdkScript.existsSync(), isTrue);

    final flutterSdk = flutterSdkScript.readAsStringSync();
    expect(
      flutterSdk,
      contains('readonly TAP_SCORE_FLUTTER_VERSION="3.38.1"'),
    );
    expect(flutterSdk, contains('readonly TAP_SCORE_FLUTTER_BIN='));
    expect(
      flutterSdk,
      contains(r'export PATH="${TAP_SCORE_FLUTTER_ROOT}/bin:${PATH}"'),
    );
    expect(
      flutterSdk,
      contains(r'"${TAP_SCORE_FLUTTER_BIN}" config --enable-web'),
    );
    expect(flutterSdk, contains('curl --fail --show-error --location'));
    expect(flutterSdk, contains('--retry 3'));
    expect(flutterSdk, contains('--continue-at -'));
    expect(flutterSdk, contains('--connect-timeout 20'));
    expect(flutterSdk, contains('--max-time 1800'));

    final cloudflareBuild = File(
      'tool/build_cloudflare_web.sh',
    ).readAsStringSync();
    expect(
      cloudflareBuild,
      contains(r'source "${SCRIPT_DIR}/flutter_sdk.sh"'),
    );
    expect(cloudflareBuild, isNot(contains('readonly FLUTTER_VERSION=')));
    expect(
      cloudflareBuild,
      contains(r'"${TAP_SCORE_FLUTTER_BIN}" pub get'),
    );
    expect(
      cloudflareBuild,
      contains(r'"${TAP_SCORE_FLUTTER_BIN}" "${build_args[@]}"'),
    );
  });

  test('CI script runs the quality gate with the pinned Flutter SDK', () {
    final ciScriptFile = File('tool/ci.sh');
    expect(ciScriptFile.existsSync(), isTrue);

    final ciScript = ciScriptFile.readAsStringSync();
    expect(ciScript, contains(r'source "${SCRIPT_DIR}/flutter_sdk.sh"'));

    final pubGet = _indexOfOrFail(
      ciScript,
      r'"${TAP_SCORE_FLUTTER_BIN}" pub get',
    );
    final analyze = _indexOfOrFail(
      ciScript,
      r'"${TAP_SCORE_FLUTTER_BIN}" analyze',
    );
    final test = _indexOfOrFail(
      ciScript,
      r'"${TAP_SCORE_FLUTTER_BIN}" test',
    );
    final build = _indexOfOrFail(
      ciScript,
      r'"${TAP_SCORE_FLUTTER_BIN}" build web',
    );

    expect(pubGet, lessThan(analyze));
    expect(analyze, lessThan(test));
    expect(test, lessThan(build));
    expect(ciScript, contains('--release'));
    expect(ciScript, contains('--base-href /'));
    expect(ciScript, contains('--pwa-strategy none'));
    expect(ciScript, contains('--no-web-resources-cdn'));
  });

  test('GitHub Actions workflow runs repository CI for PRs and main pushes', () {
    final workflowFile = File('.github/workflows/ci.yml');
    expect(workflowFile.existsSync(), isTrue);

    final workflow = workflowFile.readAsStringSync();
    expect(workflow, contains('name: CI'));
    expect(workflow, contains('pull_request:'));
    expect(workflow, contains('push:'));
    expect(workflow, contains('- main'));
    expect(workflow, contains('runs-on: ubuntu-latest'));
    expect(workflow, contains('uses: actions/checkout@v4'));
    expect(workflow, contains('run: ./tool/ci.sh'));
  });
}
