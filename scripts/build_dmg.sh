#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Latest"
PROJECT_NAME="Latest.xcodeproj"
SCHEME_NAME="Latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
WORK_DIR="${ROOT_DIR}/.build/release-dmg"
DMG_STAGE_DIR="${WORK_DIR}/dmg-stage"
DERIVED_DATA_DIR="${WORK_DIR}/DerivedData"
DEFAULT_ENTITLEMENTS_FILE="${ROOT_DIR}/Latest/Resources/Latest.entitlements"

CONFIGURATION="${CONFIGURATION:-Release}"
XCODE_DESTINATION="${XCODE_DESTINATION:-generic/platform=macOS}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
VERSION_OVERRIDE="${APP_VERSION:-}"
BUILD_OVERRIDE="${APP_BUILD:-}"
ENTITLEMENTS_SOURCE="${ENTITLEMENTS_FILE:-}"
ALLOW_DEBUGGING=0
APP_ONLY=0
OPEN_OUTPUT=0

usage() {
  cat <<'USAGE'
Usage: scripts/build_dmg.sh [options]

Builds Latest.app with xcodebuild and packages dist/Latest.dmg.

Options:
  --app-only                Build/sign/notarize only the .app bundle
  --version <value>         Override CFBundleShortVersionString after build
  --build <value>           Override CFBundleVersion after build
  --entitlements <path>     Entitlements file to use when signing
  --allow-debugging         Add com.apple.security.get-task-allow when signing
  --skip-notarization       Skip notarization/stapling even if NOTARY_PROFILE is set
  --configuration <name>    Xcode configuration to build (default: Release)
  --destination <dest>      xcodebuild destination (default: generic/platform=macOS)
  --open                    Open the resulting app or DMG when done
  -h, --help                Show this help

Environment:
  APP_SIGN_IDENTITY         Optional signing identity. Use "-" for ad-hoc signing.
  NOTARY_PROFILE            notarytool keychain profile name for notarization.
  APP_VERSION               Same as --version.
  APP_BUILD                 Same as --build.
  ENTITLEMENTS_FILE         Same as --entitlements.
  CONFIGURATION             Same as --configuration.
  XCODE_DESTINATION         Same as --destination.

Examples:
  scripts/build_dmg.sh
  APP_SIGN_IDENTITY="-" scripts/build_dmg.sh --app-only --allow-debugging --version 0.11.1 --build 1308
  APP_SIGN_IDENTITY="Developer ID Application: Your Name (ABCDE12345)" \
  NOTARY_PROFILE="LATEST_NOTARY" \
  scripts/build_dmg.sh
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-only)
      APP_ONLY=1
      shift
      ;;
    --version)
      VERSION_OVERRIDE="$2"
      shift 2
      ;;
    --build)
      BUILD_OVERRIDE="$2"
      shift 2
      ;;
    --entitlements)
      ENTITLEMENTS_SOURCE="$2"
      shift 2
      ;;
    --allow-debugging)
      ALLOW_DEBUGGING=1
      shift
      ;;
    --skip-notarization)
      SKIP_NOTARIZATION=1
      shift
      ;;
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --destination)
      XCODE_DESTINATION="$2"
      shift 2
      ;;
    --open)
      OPEN_OUTPUT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

log() {
  printf '\n[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

plist_get() {
  plutil -extract "$2" raw -o - "$1" 2>/dev/null || true
}

plist_set() {
  local plist_file="$1"
  local key="$2"
  local value="$3"

  plutil -replace "${key}" -string "${value}" "${plist_file}" 2>/dev/null || \
    plutil -insert "${key}" -string "${value}" "${plist_file}"
}

plist_set_bool() {
  local plist_file="$1"
  local key="$2"
  local value="$3"

  plutil -replace "${key}" -bool "${value}" "${plist_file}" 2>/dev/null || \
    plutil -insert "${key}" -bool "${value}" "${plist_file}"
}

write_empty_plist() {
  local plist_file="$1"
  cat > "${plist_file}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF
}

write_manifest() {
  local manifest_file="$1"
  local dmg_name="$2"
  local dmg_sha="$3"

  {
    printf '{\n'
    printf '  "app_name": "%s",\n' "${APP_NAME}"
    printf '  "bundle_id": "%s",\n' "${BUNDLE_ID}"
    printf '  "version": "%s",\n' "${APP_VERSION}"
    printf '  "build": "%s",\n' "${APP_BUILD}"
    printf '  "configuration": "%s",\n' "${CONFIGURATION}"
    printf '  "architectures": "%s",\n' "${APP_ARCHS}"
    printf '  "app_signed": %s,\n' "${APP_SIGNED}"
    printf '  "app_notarized": %s,\n' "${APP_NOTARIZED}"
    printf '  "app_bundle": "%s",\n' "$(basename "${FINAL_APP}")"
    printf '  "app_executable_sha256": "%s"' "${APP_EXEC_SHA256}"
    if [[ -n "${dmg_name}" ]]; then
      printf ',\n  "dmg_file": "%s",\n' "${dmg_name}"
      printf '  "dmg_sha256": "%s"\n' "${dmg_sha}"
    else
      printf '\n'
    fi
    printf '}\n'
  } > "${manifest_file}"
}

require_cmd xcodebuild
require_cmd hdiutil
require_cmd shasum
require_cmd cp
require_cmd ln
require_cmd rm

APP_SIGNED=false
APP_NOTARIZED=false
DMG_SHA256=""
SIGN_ENTITLEMENTS_FILE=""
ARTIFACT_BASENAME="${APP_NAME}"

if [[ -n "${NOTARY_PROFILE}" && "${SKIP_NOTARIZATION}" != "1" ]]; then
  if [[ -z "${APP_SIGN_IDENTITY}" || "${APP_SIGN_IDENTITY}" == "-" ]]; then
    echo "A real APP_SIGN_IDENTITY is required for notarization." >&2
    exit 1
  fi
  require_cmd ditto
  require_cmd xcrun
fi

if [[ -n "${APP_SIGN_IDENTITY}" ]]; then
  require_cmd codesign
fi

if [[ -z "${ENTITLEMENTS_SOURCE}" && -f "${DEFAULT_ENTITLEMENTS_FILE}" ]]; then
  ENTITLEMENTS_SOURCE="${DEFAULT_ENTITLEMENTS_FILE}"
fi

if [[ -n "${ENTITLEMENTS_SOURCE}" && ! -f "${ENTITLEMENTS_SOURCE}" ]]; then
  echo "Entitlements file not found: ${ENTITLEMENTS_SOURCE}" >&2
  exit 1
fi

if [[ "${ALLOW_DEBUGGING}" == "1" && -n "${NOTARY_PROFILE}" && "${SKIP_NOTARIZATION}" != "1" ]]; then
  echo "--allow-debugging cannot be combined with notarization." >&2
  echo "Use --skip-notarization or omit NOTARY_PROFILE for debug-signed builds." >&2
  exit 1
fi

if [[ "${OPEN_OUTPUT}" == "1" ]]; then
  require_cmd open
fi

log "Cleaning previous artifacts"
rm -rf "${WORK_DIR}" "${DIST_DIR}"
mkdir -p "${WORK_DIR}" "${DIST_DIR}"

log "Building ${APP_NAME}.app with xcodebuild"
xcodebuild \
  -project "${ROOT_DIR}/${PROJECT_NAME}" \
  -scheme "${SCHEME_NAME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  -destination "${XCODE_DESTINATION}" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

APP_DIR="${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
if [[ ! -d "${APP_DIR}" ]]; then
  echo "Built app not found: ${APP_DIR}" >&2
  exit 1
fi

APP_PLIST="${APP_DIR}/Contents/Info.plist"
APP_BINARY="${APP_DIR}/Contents/MacOS/${APP_NAME}"
DSYM_PLIST="${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app.dSYM/Contents/Info.plist"

if [[ -n "${VERSION_OVERRIDE}" ]]; then
  plist_set "${APP_PLIST}" CFBundleShortVersionString "${VERSION_OVERRIDE}"
fi

if [[ -n "${BUILD_OVERRIDE}" ]]; then
  plist_set "${APP_PLIST}" CFBundleVersion "${BUILD_OVERRIDE}"
  if [[ -f "${DSYM_PLIST}" ]]; then
    plist_set "${DSYM_PLIST}" CFBundleVersion "${BUILD_OVERRIDE}"
  fi
fi

APP_VERSION="$(plist_get "${APP_PLIST}" CFBundleShortVersionString)"
APP_BUILD="$(plist_get "${APP_PLIST}" CFBundleVersion)"
BUNDLE_ID="$(plist_get "${APP_PLIST}" CFBundleIdentifier)"
APP_ARCHS="$(lipo -archs "${APP_BINARY}" 2>/dev/null || true)"

if [[ -z "${APP_VERSION}" ]]; then
  APP_VERSION="unknown"
fi
if [[ -z "${APP_BUILD}" ]]; then
  APP_BUILD="unknown"
fi
if [[ -z "${BUNDLE_ID}" ]]; then
  BUNDLE_ID="unknown"
fi
if [[ -z "${APP_ARCHS}" ]]; then
  APP_ARCHS="unknown"
fi

ARTIFACT_BASENAME="${APP_NAME}-${APP_VERSION}"

if [[ -n "${APP_SIGN_IDENTITY}" ]]; then
  UPDATE_INSTALLER_BINARY="${APP_DIR}/Contents/Resources/LatestUpdateInstaller"
  if [[ -f "${UPDATE_INSTALLER_BINARY}" ]]; then
    log "Signing bundled update installer helper"
    HELPER_SIGN_ARGS=(--force --sign "${APP_SIGN_IDENTITY}")
    if [[ "${APP_SIGN_IDENTITY}" != "-" ]]; then
      HELPER_SIGN_ARGS+=(--timestamp --options runtime)
    fi
    codesign "${HELPER_SIGN_ARGS[@]}" "${UPDATE_INSTALLER_BINARY}"
  fi

  log "Signing app bundle"
  SIGN_ARGS=(--force --deep --sign "${APP_SIGN_IDENTITY}")
  if [[ "${APP_SIGN_IDENTITY}" != "-" ]]; then
    SIGN_ARGS+=(--timestamp --options runtime)
  fi
  if [[ -n "${ENTITLEMENTS_SOURCE}" || "${ALLOW_DEBUGGING}" == "1" ]]; then
    SIGN_ENTITLEMENTS_FILE="${WORK_DIR}/${APP_NAME}.entitlements"
    if [[ -n "${ENTITLEMENTS_SOURCE}" ]]; then
      cp "${ENTITLEMENTS_SOURCE}" "${SIGN_ENTITLEMENTS_FILE}"
    else
      write_empty_plist "${SIGN_ENTITLEMENTS_FILE}"
    fi
    if [[ "${ALLOW_DEBUGGING}" == "1" ]]; then
      plist_set_bool "${SIGN_ENTITLEMENTS_FILE}" "com\\.apple\\.security\\.get-task-allow" true
    fi
    SIGN_ARGS+=(--entitlements "${SIGN_ENTITLEMENTS_FILE}")
  fi
  codesign "${SIGN_ARGS[@]}" "${APP_DIR}"
  codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
  APP_SIGNED=true
fi

if [[ -n "${NOTARY_PROFILE}" && "${SKIP_NOTARIZATION}" != "1" ]]; then
  APP_ZIP="${WORK_DIR}/${APP_NAME}.zip"
  log "Creating zip for app notarization"
  ditto -c -k --keepParent "${APP_DIR}" "${APP_ZIP}"

  log "Submitting app for notarization"
  xcrun notarytool submit "${APP_ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait

  log "Stapling notarization ticket to app"
  xcrun stapler staple "${APP_DIR}"
  xcrun stapler validate "${APP_DIR}"
  APP_NOTARIZED=true
fi

FINAL_APP="${DIST_DIR}/${ARTIFACT_BASENAME}.app"
rm -rf "${FINAL_APP}"
cp -R "${APP_DIR}" "${FINAL_APP}"

APP_EXEC_SHA256="$(shasum -a 256 "${APP_BINARY}" | awk '{print $1}')"
APP_SHA_FILE="${DIST_DIR}/${ARTIFACT_BASENAME}.app-executable.sha256"
printf '%s  %s\n' "${APP_EXEC_SHA256}" "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" > "${APP_SHA_FILE}"

if [[ "${APP_ONLY}" == "1" ]]; then
  MANIFEST_FILE="${DIST_DIR}/${ARTIFACT_BASENAME}.build-manifest.json"
  write_manifest "${MANIFEST_FILE}" "" ""

  log "Done"
  echo "App: ${FINAL_APP}"
  echo "App executable SHA256: ${APP_EXEC_SHA256}"
  echo "Checksum file: ${APP_SHA_FILE}"
  echo "Manifest: ${MANIFEST_FILE}"
  if [[ "${OPEN_OUTPUT}" == "1" ]]; then
    open "${FINAL_APP}"
  fi
  exit 0
fi

log "Preparing DMG staging folder"
mkdir -p "${DMG_STAGE_DIR}"
cp -R "${APP_DIR}" "${DMG_STAGE_DIR}/"
ln -s /Applications "${DMG_STAGE_DIR}/Applications"

UNSIGNED_DMG="${WORK_DIR}/${ARTIFACT_BASENAME}.dmg"
FINAL_DMG="${DIST_DIR}/${ARTIFACT_BASENAME}.dmg"

log "Building DMG"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGE_DIR}" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "${UNSIGNED_DMG}"

if [[ -n "${APP_SIGN_IDENTITY}" && "${APP_SIGN_IDENTITY}" != "-" ]]; then
  log "Signing DMG"
  codesign --force --timestamp --sign "${APP_SIGN_IDENTITY}" "${UNSIGNED_DMG}"
  codesign --verify --verbose=2 "${UNSIGNED_DMG}"
fi

if [[ -n "${NOTARY_PROFILE}" && "${SKIP_NOTARIZATION}" != "1" ]]; then
  log "Submitting DMG for notarization"
  xcrun notarytool submit "${UNSIGNED_DMG}" --keychain-profile "${NOTARY_PROFILE}" --wait

  log "Stapling notarization ticket to DMG"
  xcrun stapler staple "${UNSIGNED_DMG}"
  xcrun stapler validate "${UNSIGNED_DMG}"
fi

mv -f "${UNSIGNED_DMG}" "${FINAL_DMG}"
DMG_SHA256="$(shasum -a 256 "${FINAL_DMG}" | awk '{print $1}')"
DMG_SHA_FILE="${FINAL_DMG}.sha256"
printf '%s  %s\n' "${DMG_SHA256}" "$(basename "${FINAL_DMG}")" > "${DMG_SHA_FILE}"

MANIFEST_FILE="${DIST_DIR}/${ARTIFACT_BASENAME}.build-manifest.json"
write_manifest "${MANIFEST_FILE}" "$(basename "${FINAL_DMG}")" "${DMG_SHA256}"

log "Done"
echo "DMG: ${FINAL_DMG}"
echo "DMG SHA256: ${DMG_SHA256}"
echo "App executable SHA256: ${APP_EXEC_SHA256}"
echo "Checksum file: ${DMG_SHA_FILE}"
echo "Checksum file: ${APP_SHA_FILE}"
echo "Manifest: ${MANIFEST_FILE}"
if [[ "${OPEN_OUTPUT}" == "1" ]]; then
  open "${FINAL_DMG}"
fi
