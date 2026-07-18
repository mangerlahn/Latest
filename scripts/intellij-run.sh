#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/intellij-derived-data}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$BUILD_CONFIGURATION/Latest.app"

"$ROOT_DIR/scripts/intellij-build.sh" "$@"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app bundle was not produced at $APP_PATH" >&2
  exit 1
fi

/usr/bin/open -n "$APP_PATH"
