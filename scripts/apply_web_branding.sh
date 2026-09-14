#!/usr/bin/env bash

set -euo pipefail

TENANT="${1:-}"

if [[ -z "$TENANT" ]]; then
  echo "Usage: $0 <tenant>"
  exit 1
fi

SOURCE_DIR="web/tenants/$TENANT"
BUILD_DIR="build/web"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Tenant web branding not found: $SOURCE_DIR"
  exit 1
fi

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "Flutter web build not found: $BUILD_DIR"
  exit 1
fi

for required in \
  "$SOURCE_DIR/manifest.webmanifest" \
  "$SOURCE_DIR/favicon.png" \
  "$SOURCE_DIR/icons"
do
  if [[ ! -e "$required" ]]; then
    echo "Missing tenant branding asset: $required"
    exit 1
  fi
done

echo "🎨 Applying web branding: $TENANT"

cp \
  "$SOURCE_DIR/manifest.webmanifest" \
  "$BUILD_DIR/manifest.webmanifest"

cp \
  "$SOURCE_DIR/favicon.png" \
  "$BUILD_DIR/favicon.png"

rm -rf "$BUILD_DIR/icons"
mkdir -p "$BUILD_DIR/icons"

cp -R \
  "$SOURCE_DIR/icons/." \
  "$BUILD_DIR/icons/"

echo "✅ Applied web branding: $TENANT"