#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILD_MODE="${1:-js}"
readonly BUILD_OUTPUT_DIR="build/web"

source "${SCRIPT_DIR}/flutter_sdk.sh"

"${TAP_SCORE_FLUTTER_BIN}" pub get

build_args=(
  build
  web
  --release
  --base-href /
  --pwa-strategy none
  --no-web-resources-cdn
)

case "${BUILD_MODE}" in
  js)
    ;;
  wasm)
    build_args+=(--wasm)
    ;;
  *)
    echo "Unsupported build mode: ${BUILD_MODE}" >&2
    echo "Expected one of: js, wasm" >&2
    exit 1
    ;;
esac

"${TAP_SCORE_FLUTTER_BIN}" "${build_args[@]}"

# Remove native-only SoundFont from web output (only used on iOS/Android via flutter_midi_pro)
rm -f "${BUILD_OUTPUT_DIR}/assets/assets/soundfonts/piano.sf2"
# Remove debug symbol maps (not needed in production, saves ~4MB upload)
find "${BUILD_OUTPUT_DIR}/canvaskit" -name '*.symbols' -delete

"${SCRIPT_DIR}/inject_web_deploy_id.sh" "${BUILD_OUTPUT_DIR}"

cat <<'EOF'
After deploying this build, purge Cloudflare cache for:
  /
  /index.html
  /flutter_bootstrap.js
  /main.dart.js
  /flutter.js
EOF
