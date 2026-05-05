#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/flutter_sdk.sh"

cd "${REPO_ROOT}"

"${TAP_SCORE_FLUTTER_BIN}" pub get
"${TAP_SCORE_FLUTTER_BIN}" analyze
"${TAP_SCORE_FLUTTER_BIN}" test
"${TAP_SCORE_FLUTTER_BIN}" build web --release --base-href / --pwa-strategy none --no-web-resources-cdn
