#!/usr/bin/env bash

set -euo pipefail

TENANT="${1:-}"

if [[ -z "$TENANT" ]]; then
  echo "Usage: $0 <tenant> -- <flutter command...>"
  exit 2
fi

shift

if [[ "${1:-}" == "--" ]]; then
  shift
fi

if [[ "$#" -eq 0 ]]; then
  echo "❌ Missing command to run."
  echo "Usage: $0 <tenant> -- flutter run ..."
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WEB_DIR="$ROOT_DIR/web"
TENANT_DIR="$WEB_DIR/tenants/$TENANT"

GENERIC_MANIFEST="$WEB_DIR/manifest.webmanifest"
GENERIC_FAVICON="$WEB_DIR/favicon.png"
GENERIC_ICONS="$WEB_DIR/icons"

TENANT_FAVICON="$TENANT_DIR/favicon.png"
TENANT_ICONS="$TENANT_DIR/icons"

# Support both naming conventions while tenants are being standardised.
if [[ -f "$TENANT_DIR/manifest.webmanifest" ]]; then
  TENANT_MANIFEST="$TENANT_DIR/manifest.webmanifest"
elif [[ -f "$TENANT_DIR/manifest.json" ]]; then
  TENANT_MANIFEST="$TENANT_DIR/manifest.json"
else
  echo "❌ Missing tenant manifest:"
  echo "   $TENANT_DIR/manifest.webmanifest"
  echo "   or"
  echo "   $TENANT_DIR/manifest.json"
  exit 2
fi

require_path() {
  local path="$1"

  if [[ ! -e "$path" ]]; then
    echo "❌ Missing web branding asset: $path"
    exit 2
  fi
}

require_path "$TENANT_FAVICON"
require_path "$TENANT_ICONS"
require_path "$GENERIC_MANIFEST"
require_path "$GENERIC_FAVICON"

BACKUP_DIR="$(mktemp -d)"

HAD_GENERIC_ICONS=0

if [[ -d "$GENERIC_ICONS" ]]; then
  HAD_GENERIC_ICONS=1
fi

cleanup() {
  local exit_code=$?

  trap - EXIT INT TERM

  echo
  echo "🧹 Restoring generic AfyaKit web branding…"

  cp "$BACKUP_DIR/manifest.webmanifest" "$GENERIC_MANIFEST"
  cp "$BACKUP_DIR/favicon.png" "$GENERIC_FAVICON"

  rm -rf "$GENERIC_ICONS"

  if [[ "$HAD_GENERIC_ICONS" == "1" ]]; then
    cp -R "$BACKUP_DIR/icons" "$GENERIC_ICONS"
  fi

  rm -rf "$BACKUP_DIR"

  echo "✅ Generic web branding restored"

  exit "$exit_code"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "📦 Backing up generic AfyaKit web branding…"

cp "$GENERIC_MANIFEST" "$BACKUP_DIR/manifest.webmanifest"
cp "$GENERIC_FAVICON" "$BACKUP_DIR/favicon.png"

if [[ "$HAD_GENERIC_ICONS" == "1" ]]; then
  cp -R "$GENERIC_ICONS" "$BACKUP_DIR/icons"
fi

echo "🎨 Applying Chrome development branding: $TENANT"

cp "$TENANT_MANIFEST" "$GENERIC_MANIFEST"
cp "$TENANT_FAVICON" "$GENERIC_FAVICON"

rm -rf "$GENERIC_ICONS"
mkdir -p "$GENERIC_ICONS"

cp -R "$TENANT_ICONS/." "$GENERIC_ICONS/"

echo "✅ Applied Chrome development branding: $TENANT"
echo "🚀 Starting Flutter…"

cd "$ROOT_DIR"

"$@"