#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Latest.xcodeproj"
SCHEME_NAME="Latest"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/intellij-derived-data}"

resolve_xcodebuild() {
  if /usr/bin/xcrun --find xcodebuild >/dev/null 2>&1; then
    return 0
  fi

  local -a candidates=(
    "${XCODE_APP_PATH:-}"
    "/Applications/Xcode.app"
    "/Applications/Xcode-beta.app"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -d "$candidate/Contents/Developer" ]]; then
      export DEVELOPER_DIR="$candidate/Contents/Developer"
      if /usr/bin/xcrun --find xcodebuild >/dev/null 2>&1; then
        return 0
      fi
    fi
  done

  cat >&2 <<'EOF'
Unable to find Xcode's build tools.

Install Xcode and make sure the active developer directory points at it:
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

If Xcode is installed somewhere else, set XCODE_APP_PATH before running this script.
EOF
  return 1
}

resolve_xcodebuild

mkdir -p "$DERIVED_DATA_PATH"

/usr/bin/xcrun xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -configuration "$BUILD_CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build \
  "$@"
