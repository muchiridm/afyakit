#!/usr/bin/env bash

set -euo pipefail

TENANT_ID="${1:-}"
APP_ID="${2:-}"

usage() {
  echo "Usage: $0 <tenantId> <appId> -- <flutter command...>"
  echo "       $0 hq afyakit -- <flutter command...>"
}

if [[ -z "$TENANT_ID" || -z "$APP_ID" ]]; then
  usage
  exit 2
fi

validate_id() {
  local value="$1"
  local label="$2"

  if [[ ! "$value" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    echo "❌ Invalid $label: $value" >&2
    exit 2
  fi
}

validate_id "$TENANT_ID" "tenant ID"
validate_id "$APP_ID" "app ID"

shift 2

if [[ "${1:-}" == "--" ]]; then
  shift
fi

if [[ "$#" -eq 0 ]]; then
  echo "❌ Missing command to run."
  usage
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WEB_DIR="$ROOT_DIR/web"

# Explicit HQ branding exception.
if [[ "$TENANT_ID" == "hq" ]]; then
  if [[ "$APP_ID" != "afyakit" ]]; then
    echo "❌ HQ branding requires app ID: afyakit" >&2
    exit 2
  fi

  BRANDING_DIR="$WEB_DIR/tenants/afyakit"
else
  BRANDING_DIR="$WEB_DIR/tenants/$TENANT_ID/apps/$APP_ID"
fi

if [[ ! -d "$BRANDING_DIR" ]]; then
  echo "❌ Missing Web branding directory:"
  echo "   $BRANDING_DIR"
  exit 2
fi

GENERIC_MANIFEST="$WEB_DIR/manifest.webmanifest"
GENERIC_FAVICON="$WEB_DIR/favicon.png"
GENERIC_ICONS="$WEB_DIR/icons"

APP_FAVICON="$BRANDING_DIR/favicon.png"
APP_ICONS="$BRANDING_DIR/icons"

# Support the existing HQ manifest.json.
if [[ -f "$BRANDING_DIR/manifest.webmanifest" ]]; then
  APP_MANIFEST="$BRANDING_DIR/manifest.webmanifest"
elif [[ -f "$BRANDING_DIR/manifest.json" ]]; then
  APP_MANIFEST="$BRANDING_DIR/manifest.json"
else
  echo "❌ Missing Web manifest:"
  echo "   $BRANDING_DIR/manifest.webmanifest"
  echo "   or"
  echo "   $BRANDING_DIR/manifest.json"
  exit 2
fi

require_file() {
  local path="$1"

  if [[ ! -f "$path" ]]; then
    echo "❌ Missing Web branding file: $path"
    exit 2
  fi
}

require_dir() {
  local path="$1"

  if [[ ! -d "$path" ]]; then
    echo "❌ Missing Web branding directory: $path"
    exit 2
  fi
}

# Existing HQ branding may use the shared AfyaKit favicon.
if [[ "$TENANT_ID" == "hq" && ! -f "$APP_FAVICON" ]]; then
  APP_FAVICON="$GENERIC_FAVICON"
fi

require_file "$APP_MANIFEST"
require_file "$APP_FAVICON"
require_dir "$APP_ICONS"

require_file "$GENERIC_MANIFEST"
require_file "$GENERIC_FAVICON"

BACKUP_DIR="$(mktemp -d)"

HAD_GENERIC_ICONS=0

if [[ -d "$GENERIC_ICONS" ]]; then
  HAD_GENERIC_ICONS=1
fi

echo "📦 Backing up shared AfyaKit Web branding…"

if ! cp "$GENERIC_MANIFEST" \
  "$BACKUP_DIR/manifest.webmanifest" ||
  ! cp "$GENERIC_FAVICON" \
    "$BACKUP_DIR/favicon.png"; then

  rm -rf "$BACKUP_DIR"
  echo "❌ Could not back up shared Web branding." >&2
  exit 2
fi

if [[ "$HAD_GENERIC_ICONS" == "1" ]]; then
  if ! cp -R "$GENERIC_ICONS" "$BACKUP_DIR/icons"; then
    rm -rf "$BACKUP_DIR"
    echo "❌ Could not back up shared Web icons." >&2
    exit 2
  fi
fi

cleanup() {
  local exit_code=$?

  trap - EXIT INT TERM

  echo
  echo "🧹 Restoring shared AfyaKit Web branding…"

  cp "$BACKUP_DIR/manifest.webmanifest" \
    "$GENERIC_MANIFEST" || true

  cp "$BACKUP_DIR/favicon.png" \
    "$GENERIC_FAVICON" || true

  rm -rf "$GENERIC_ICONS"

  if [[ "$HAD_GENERIC_ICONS" == "1" ]]; then
    cp -R "$BACKUP_DIR/icons" \
      "$GENERIC_ICONS" || true
  fi

  rm -rf "$BACKUP_DIR"

  echo "✅ Shared Web branding restoration attempted"

  exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "🎨 Applying Web branding"
echo "   Tenant: $TENANT_ID"
echo "   App:    $APP_ID"
echo "   Source: $BRANDING_DIR"

cp "$APP_MANIFEST" \
  "$GENERIC_MANIFEST"

# If HQ uses the shared favicon, do not copy the file onto itself.
if [[ "$APP_FAVICON" != "$GENERIC_FAVICON" ]]; then
  cp "$APP_FAVICON" \
    "$GENERIC_FAVICON"
fi

rm -rf "$GENERIC_ICONS"
mkdir -p "$GENERIC_ICONS"

cp -R "$APP_ICONS/." \
  "$GENERIC_ICONS/"

echo "✅ Applied Web branding: $TENANT_ID / $APP_ID"
echo "🚀 Starting Flutter…"

cd "$ROOT_DIR"

"$@"