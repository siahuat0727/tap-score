#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BUILD_MODE="${1:-js}"
readonly FLUTTER_VERSION="3.38.1"
readonly FLUTTER_CHANNEL="stable"
readonly FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
readonly FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/${FLUTTER_ARCHIVE}"
readonly CACHE_ROOT="${HOME}/.cache/tap-score"
readonly FLUTTER_ROOT="${CACHE_ROOT}/flutter-${FLUTTER_VERSION}"
readonly FLUTTER_BIN="${FLUTTER_ROOT}/bin/flutter"
readonly BUILD_OUTPUT_DIR="build/web"

if [[ ! -x "${FLUTTER_BIN}" ]]; then
  mkdir -p "${CACHE_ROOT}"
  curl -fsSL "${FLUTTER_URL}" -o "${CACHE_ROOT}/${FLUTTER_ARCHIVE}"
  rm -rf "${FLUTTER_ROOT}"
  tar -xJf "${CACHE_ROOT}/${FLUTTER_ARCHIVE}" -C "${CACHE_ROOT}"
  mv "${CACHE_ROOT}/flutter" "${FLUTTER_ROOT}"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"

"${FLUTTER_BIN}" config --enable-web
"${FLUTTER_BIN}" --version
"${FLUTTER_BIN}" pub get

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

"${FLUTTER_BIN}" "${build_args[@]}"

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
