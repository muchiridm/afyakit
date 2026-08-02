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
  echo "Missing command to run."
  echo "Usage: $0 <tenant> -- flutter run ..."
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WEB_DIR="$ROOT_DIR/web"
TENANT_DIR="$WEB_DIR/tenants/$TENANT"

TENANT_MANIFEST="$TENANT_DIR/manifest.webmanifest"
TENANT_FAVICON="$TENANT_DIR/favicon.png"
TENANT_ICONS="$TENANT_DIR/icons"

GENERIC_MANIFEST="$WEB_DIR/manifest.webmanifest"
GENERIC_FAVICON="$WEB_DIR/favicon.png"
GENERIC_ICONS="$WEB_DIR/icons"

for required in \
  "$TENANT_MANIFEST" \
  "$TENANT_FAVICON" \
  "$TENANT_ICONS" \
  "$GENERIC_MANIFEST" \
  "$GENERIC_FAVICON" \
  "$GENERIC_ICONS"
do
  if [[ ! -e "$required" ]]; then
    echo "❌ Missing web branding asset: $required"
    exit 2
  fi
done

BACKUP_DIR="$(mktemp -d)"

restore_generic_branding() {
  local exit_code=$?

  echo
  echo "🧹 Restoring generic AfyaKit web branding…"

  rm -rf "$GENERIC_ICONS"

  cp "$BACKUP_DIR/manifest.webmanifest" "$GENERIC_MANIFEST"
  cp "$BACKUP_DIR/favicon.png" "$GENERIC_FAVICON"
  cp -R "$BACKUP_DIR/icons" "$GENERIC_ICONS"

  rm -rf "$BACKUP_DIR"

  echo "✅ Generic web branding restored"

  exit "$exit_code"
}

trap restore_generic_branding EXIT INT TERM

echo "📦 Backing up generic AfyaKit web branding…"

cp "$GENERIC_MANIFEST" "$BACKUP_DIR/manifest.webmanifest"
cp "$GENERIC_FAVICON" "$BACKUP_DIR/favicon.png"
cp -R "$GENERIC_ICONS" "$BACKUP_DIR/icons"

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