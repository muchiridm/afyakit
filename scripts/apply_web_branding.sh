#!/usr/bin/env bash

set -euo pipefail

TENANT_ID="${1:-}"
APP_ID="${2:-}"

usage() {
  echo "Usage: $0 <tenantId> <appId>"
  echo "       $0 hq afyakit"
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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WEB_DIR="$ROOT_DIR/web"
BUILD_DIR="$ROOT_DIR/build/web"

# HQ has an explicit bootstrap and branding identity.
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
  echo "❌ Web branding directory not found:"
  echo "   $BRANDING_DIR"
  exit 2
fi

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "❌ Flutter Web build not found:"
  echo "   $BUILD_DIR"
  echo "   Build the selected application first."
  exit 2
fi

# AfyaKit HQ currently uses manifest.json.
# Both manifest filenames are accepted as source files.
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

APP_FAVICON="$BRANDING_DIR/favicon.png"
APP_ICONS="$BRANDING_DIR/icons"

# Allow the existing HQ directory to use the shared AfyaKit favicon.
if [[ "$TENANT_ID" == "hq" && ! -f "$APP_FAVICON" ]]; then
  APP_FAVICON="$WEB_DIR/favicon.png"
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

# Validate everything before modifying build/web.
require_file "$APP_MANIFEST"
require_file "$APP_FAVICON"
require_dir "$APP_ICONS"

echo "🎨 Applying Web branding"
echo "   Tenant: $TENANT_ID"
echo "   App:    $APP_ID"
echo "   Source: $BRANDING_DIR"
echo "   Target: $BUILD_DIR"

cp "$APP_MANIFEST" \
  "$BUILD_DIR/manifest.webmanifest"

cp "$APP_FAVICON" \
  "$BUILD_DIR/favicon.png"

rm -rf "$BUILD_DIR/icons"
mkdir -p "$BUILD_DIR/icons"

cp -R "$APP_ICONS/." \
  "$BUILD_DIR/icons/"

echo "✅ Applied Web branding: $TENANT_ID / $APP_ID"