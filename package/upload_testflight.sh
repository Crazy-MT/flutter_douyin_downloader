#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXPORT_OPTIONS_PLIST="$SCRIPT_DIR/ExportOptionsTestFlight.plist"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
FLUTTER_COMMAND="${FLUTTER_COMMAND:-}"
SKIP_BUILD="${SKIP_BUILD:-0}"

ASC_API_KEY_ID="${ASC_API_KEY_ID:-}"
ASC_API_ISSUER_ID="${ASC_API_ISSUER_ID:-}"
ASC_API_KEY_PATH="${ASC_API_KEY_PATH:-}"

usage() {
  cat <<'USAGE'
Usage:
  ASC_API_KEY_ID=XXXXXXXXXX \
  ASC_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
  ASC_API_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8 \
  ./package/upload_testflight.sh

Optional environment variables:
  BUILD_NAME=1.9.2       Override Flutter build-name.
  BUILD_NUMBER=192       Override Flutter build-number.
  FLUTTER_COMMAND=flutter Override the Flutter command. Defaults to fvm flutter.
  IPA_PATH=/path/app.ipa Upload an existing ipa.
  SKIP_BUILD=1           Skip Flutter build and upload IPA_PATH/latest ipa.

The script builds a release ipa with App Store Connect export options and then
uploads it to TestFlight with xcrun altool. Keep the .p8 key outside git.
USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

resolve_flutter_command() {
  if [[ -n "$FLUTTER_COMMAND" ]]; then
    echo "$FLUTTER_COMMAND"
    return
  fi

  if command -v fvm >/dev/null 2>&1; then
    echo "fvm flutter"
    return
  fi

  require_command flutter
  echo "flutter"
}

absolute_path() {
  local path="$1"
  local dir
  local base

  dir="$(cd "$(dirname "$path")" && pwd)"
  base="$(basename "$path")"
  echo "$dir/$base"
}

latest_ipa_path() {
  local ipa_files=()

  shopt -s nullglob
  ipa_files=("$PROJECT_DIR"/build/ios/ipa/*.ipa)
  shopt -u nullglob

  ((${#ipa_files[@]} > 0)) || return 0
  ls -t "${ipa_files[@]}" | head -n 1
}

build_ipa() {
  local flutter_command="$1"
  local build_args=(
    build ipa
    --release
    "--export-options-plist=$EXPORT_OPTIONS_PLIST"
  )

  if [[ -n "$BUILD_NAME" ]]; then
    build_args+=("--build-name=$BUILD_NAME")
  fi

  if [[ -n "$BUILD_NUMBER" ]]; then
    build_args+=("--build-number=$BUILD_NUMBER")
  fi

  echo "Building TestFlight ipa..."
  cd "$PROJECT_DIR"
  # shellcheck disable=SC2086
  $flutter_command "${build_args[@]}"
}

prepare_api_key_dir() {
  local temp_dir="$1"
  local private_key_name="AuthKey_${ASC_API_KEY_ID}.p8"

  mkdir -p "$temp_dir/private_keys"
  ln -sf "$ASC_API_KEY_PATH" "$temp_dir/private_keys/$private_key_name"
}

upload_ipa() {
  local ipa_path="$1"
  local upload_work_dir

  [[ -n "$ASC_API_KEY_ID" ]] || fail "ASC_API_KEY_ID is required"
  [[ -n "$ASC_API_ISSUER_ID" ]] || fail "ASC_API_ISSUER_ID is required"
  [[ -n "$ASC_API_KEY_PATH" ]] || fail "ASC_API_KEY_PATH is required"
  [[ -f "$ASC_API_KEY_PATH" ]] || fail "API key not found: $ASC_API_KEY_PATH"
  require_command xcrun

  upload_work_dir="$(mktemp -d)"
  trap 'rm -rf "$upload_work_dir"' EXIT
  prepare_api_key_dir "$upload_work_dir"

  echo "Uploading to TestFlight: $ipa_path"
  (
    cd "$upload_work_dir"
    xcrun altool \
      --upload-app \
      --type ios \
      --file "$ipa_path" \
      --apiKey "$ASC_API_KEY_ID" \
      --apiIssuer "$ASC_API_ISSUER_ID"
  )
}

main() {
  local flutter_command
  local ipa_path="${IPA_PATH:-}"

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  [[ -f "$EXPORT_OPTIONS_PLIST" ]] \
    || fail "missing export options: $EXPORT_OPTIONS_PLIST"

  if [[ "$SKIP_BUILD" != "1" ]]; then
    flutter_command="$(resolve_flutter_command)"
    build_ipa "$flutter_command"
  fi

  if [[ -z "$ipa_path" ]]; then
    ipa_path="$(latest_ipa_path)"
  fi

  [[ -n "$ipa_path" ]] || fail "no ipa found under build/ios/ipa"
  ipa_path="$(absolute_path "$ipa_path")"
  [[ -f "$ipa_path" ]] || fail "ipa not found: $ipa_path"

  upload_ipa "$ipa_path"
  echo "Upload submitted. Processing status is visible in App Store Connect."
}

main "$@"
