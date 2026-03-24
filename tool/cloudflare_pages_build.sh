#!/usr/bin/env bash

set -euo pipefail

readonly FLUTTER_VERSION="3.38.1"
readonly FLUTTER_CHANNEL="stable"
readonly FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
readonly FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/${FLUTTER_ARCHIVE}"
readonly CACHE_ROOT="${HOME}/.cache/tap-score"
readonly FLUTTER_ROOT="${CACHE_ROOT}/flutter-${FLUTTER_VERSION}"
readonly FLUTTER_BIN="${FLUTTER_ROOT}/bin/flutter"

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
"${FLUTTER_BIN}" build web --release --base-href /