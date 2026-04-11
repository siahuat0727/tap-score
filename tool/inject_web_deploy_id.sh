#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PLACEHOLDER="__TAP_SCORE_DEPLOY_ID__"
readonly OUTPUT_DIR="${1:-}"

if [[ -z "${OUTPUT_DIR}" ]]; then
  echo "Usage: $0 <web-build-output-dir>" >&2
  exit 1
fi

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "Web build output directory not found: ${OUTPUT_DIR}" >&2
  exit 1
fi

resolve_deploy_id() {
  if [[ -n "${TAP_SCORE_DEPLOY_ID:-}" ]]; then
    printf '%s\n' "${TAP_SCORE_DEPLOY_ID}"
    return
  fi

  if [[ -n "${CF_PAGES_COMMIT_SHA:-}" ]]; then
    printf '%s\n' "${CF_PAGES_COMMIT_SHA}"
    return
  fi

  if git -C "${REPO_ROOT}" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "${REPO_ROOT}" rev-parse --short=12 HEAD
    return
  fi

  echo "Unable to resolve a deploy id. Set TAP_SCORE_DEPLOY_ID or CF_PAGES_COMMIT_SHA." >&2
  exit 1
}

readonly DEPLOY_ID="$(resolve_deploy_id)"
readonly INDEX_HTML="${OUTPUT_DIR}/index.html"
readonly BOOTSTRAP_JS="${OUTPUT_DIR}/flutter_bootstrap.js"

if [[ ! -f "${INDEX_HTML}" ]]; then
  echo "Expected build output file not found: ${INDEX_HTML}" >&2
  exit 1
fi

if [[ ! -f "${BOOTSTRAP_JS}" ]]; then
  echo "Expected build output file not found: ${BOOTSTRAP_JS}" >&2
  exit 1
fi

if [[ ! "${DEPLOY_ID}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Deploy id contains unsupported characters: ${DEPLOY_ID}" >&2
  exit 1
fi

export TAP_SCORE_DEPLOY_ID_REPLACEMENT="${DEPLOY_ID}"
perl -0pi -e 's/__TAP_SCORE_DEPLOY_ID__/$ENV{TAP_SCORE_DEPLOY_ID_REPLACEMENT}/g' \
  "${INDEX_HTML}" \
  "${BOOTSTRAP_JS}"

if rg --fixed-strings --quiet "${PLACEHOLDER}" "${INDEX_HTML}" "${BOOTSTRAP_JS}"; then
  echo "Deploy id placeholder replacement was incomplete." >&2
  exit 1
fi

printf 'Injected deploy id %s into %s\n' "${DEPLOY_ID}" "${OUTPUT_DIR}"
