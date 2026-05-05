#!/usr/bin/env bash

set -euo pipefail

readonly TAP_SCORE_FLUTTER_VERSION="3.38.1"
readonly TAP_SCORE_FLUTTER_CHANNEL="stable"
readonly TAP_SCORE_CACHE_ROOT="${HOME}/.cache/tap-score"

tap_score_os="$(uname -s)"
tap_score_arch="$(uname -m)"

case "${tap_score_os}:${tap_score_arch}" in
  Linux:x86_64)
    readonly TAP_SCORE_FLUTTER_PLATFORM="linux-x64"
    readonly TAP_SCORE_FLUTTER_ARCHIVE="flutter_linux_${TAP_SCORE_FLUTTER_VERSION}-${TAP_SCORE_FLUTTER_CHANNEL}.tar.xz"
    readonly TAP_SCORE_FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${TAP_SCORE_FLUTTER_CHANNEL}/linux/${TAP_SCORE_FLUTTER_ARCHIVE}"
    readonly TAP_SCORE_FLUTTER_EXTRACT_MODE="tar_xz"
    ;;
  Darwin:arm64)
    readonly TAP_SCORE_FLUTTER_PLATFORM="macos-arm64"
    readonly TAP_SCORE_FLUTTER_ARCHIVE="flutter_macos_arm64_${TAP_SCORE_FLUTTER_VERSION}-${TAP_SCORE_FLUTTER_CHANNEL}.zip"
    readonly TAP_SCORE_FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${TAP_SCORE_FLUTTER_CHANNEL}/macos/${TAP_SCORE_FLUTTER_ARCHIVE}"
    readonly TAP_SCORE_FLUTTER_EXTRACT_MODE="zip"
    ;;
  Darwin:x86_64)
    readonly TAP_SCORE_FLUTTER_PLATFORM="macos-x64"
    readonly TAP_SCORE_FLUTTER_ARCHIVE="flutter_macos_${TAP_SCORE_FLUTTER_VERSION}-${TAP_SCORE_FLUTTER_CHANNEL}.zip"
    readonly TAP_SCORE_FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${TAP_SCORE_FLUTTER_CHANNEL}/macos/${TAP_SCORE_FLUTTER_ARCHIVE}"
    readonly TAP_SCORE_FLUTTER_EXTRACT_MODE="zip"
    ;;
  *)
    echo "Unsupported Flutter SDK platform: ${tap_score_os} ${tap_score_arch}" >&2
    exit 1
    ;;
esac

readonly TAP_SCORE_FLUTTER_ROOT="${TAP_SCORE_CACHE_ROOT}/flutter-${TAP_SCORE_FLUTTER_PLATFORM}-${TAP_SCORE_FLUTTER_VERSION}"
readonly TAP_SCORE_FLUTTER_BIN="${TAP_SCORE_FLUTTER_ROOT}/bin/flutter"

if [[ ! -x "${TAP_SCORE_FLUTTER_BIN}" ]]; then
  mkdir -p "${TAP_SCORE_CACHE_ROOT}"
  curl --fail --show-error --location \
    --retry 3 \
    --continue-at - \
    --connect-timeout 20 \
    --max-time 1800 \
    "${TAP_SCORE_FLUTTER_URL}" \
    -o "${TAP_SCORE_CACHE_ROOT}/${TAP_SCORE_FLUTTER_ARCHIVE}"
  rm -rf "${TAP_SCORE_FLUTTER_ROOT}" "${TAP_SCORE_CACHE_ROOT}/flutter"

  case "${TAP_SCORE_FLUTTER_EXTRACT_MODE}" in
    tar_xz)
      tar -xJf "${TAP_SCORE_CACHE_ROOT}/${TAP_SCORE_FLUTTER_ARCHIVE}" -C "${TAP_SCORE_CACHE_ROOT}"
      ;;
    zip)
      unzip -q "${TAP_SCORE_CACHE_ROOT}/${TAP_SCORE_FLUTTER_ARCHIVE}" -d "${TAP_SCORE_CACHE_ROOT}"
      ;;
  esac

  mv "${TAP_SCORE_CACHE_ROOT}/flutter" "${TAP_SCORE_FLUTTER_ROOT}"
fi

export PATH="${TAP_SCORE_FLUTTER_ROOT}/bin:${PATH}"

"${TAP_SCORE_FLUTTER_BIN}" config --enable-web
"${TAP_SCORE_FLUTTER_BIN}" --version
