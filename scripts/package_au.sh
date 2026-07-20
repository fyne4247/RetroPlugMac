#!/bin/bash
# Package the premake-built AU binary into a proper .component and install it.
# Usage: package_au.sh [configuration] [install-directory]
# A system-wide install usually requires: sudo package_au.sh Release /Library/Audio/Plug-Ins/Components
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-Debug}"
INSTALL_DIR="${2:-$HOME/Library/Audio/Plug-Ins/Components}"
BIN_DIR="$ROOT/build/xcode4/bin/x64/$CONFIG"
PRODUCT="RetroPlugMac"
LEGACY_PRODUCT="RetroPlug"
# Premake may emit either name depending on PRODUCT_NAME settings
if [[ -f "$BIN_DIR/RetroPlugMac" ]]; then
  BIN="$BIN_DIR/RetroPlugMac"
elif [[ -f "$BIN_DIR/RetroPlug" ]]; then
  BIN="$BIN_DIR/RetroPlug"
elif [[ -f "$BIN_DIR/RetroPlug_auv2_x64" ]]; then
  BIN="$BIN_DIR/RetroPlug_auv2_x64"
else
  echo "error: AU binary not found under $BIN_DIR" >&2
  ls -la "$BIN_DIR" >&2 || true
  exit 1
fi

DEST="$BIN_DIR/$PRODUCT.component"
echo "Packaging $BIN -> $DEST"

rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"
cp "$BIN" "$DEST/Contents/MacOS/$PRODUCT"
chmod +x "$DEST/Contents/MacOS/$PRODUCT"
cp "$ROOT/resources/RetroPlugMac-AU-Info.plist" "$DEST/Contents/Info.plist"
cp "$ROOT/resources/fonts/"* "$DEST/Contents/Resources/" 2>/dev/null || true
printf 'BNDL????' > "$DEST/Contents/PkgInfo"

# The premake output is only a linker-signed Mach-O. Once it is wrapped with
# an Info.plist and resources, sign the completed bundle so Audio Component
# Registrar accepts the package. An ad-hoc signature is sufficient for local
# use and does not require an Apple Developer account.
codesign --force --deep --sign - "$DEST"

if [[ -d "$INSTALL_DIR" && ! -w "$INSTALL_DIR" ]]; then
  echo "error: install directory is not writable: $INSTALL_DIR" >&2
  echo "rerun with administrator privileges for a system-wide install" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
TARGET="$INSTALL_DIR/$PRODUCT.component"
LEGACY_TARGET="$INSTALL_DIR/$LEGACY_PRODUCT.component"
STAGING="$INSTALL_DIR/.$PRODUCT.component.install.$$"
BACKUP="$INSTALL_DIR/.$PRODUCT.component.previous.$$"
LEGACY_BACKUP="$INSTALL_DIR/.$LEGACY_PRODUCT.component.migrated.$$"

# Finish the copy before moving the existing component out of the way. Both
# renames then occur on the destination filesystem and can be rolled back.
rm -rf "$STAGING" "$BACKUP" "$LEGACY_BACKUP"
cp -R "$DEST" "$STAGING"
if [[ -e "$TARGET" ]]; then
  mv "$TARGET" "$BACKUP"
fi

# Migrate only our pre-rebrand component. An official RetroPlug build may use
# the same filename later, but it has a different subtype and must be preserved.
if [[ -e "$LEGACY_TARGET" ]]; then
  LEGACY_SUBTYPE="$(/usr/libexec/PlistBuddy -c 'Print :AudioComponents:0:subtype' "$LEGACY_TARGET/Contents/Info.plist" 2>/dev/null || true)"
  LEGACY_MFR="$(/usr/libexec/PlistBuddy -c 'Print :AudioComponents:0:manufacturer' "$LEGACY_TARGET/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$LEGACY_SUBTYPE" == "2wvF" && "$LEGACY_MFR" == "Tmtt" ]]; then
    mv "$LEGACY_TARGET" "$LEGACY_BACKUP"
  fi
fi

if ! mv "$STAGING" "$TARGET"; then
  if [[ -e "$BACKUP" ]]; then
    mv "$BACKUP" "$TARGET"
  fi
  if [[ -e "$LEGACY_BACKUP" ]]; then
    mv "$LEGACY_BACKUP" "$LEGACY_TARGET"
  fi
  exit 1
fi
rm -rf "$BACKUP" "$LEGACY_BACKUP"
killall -9 AudioComponentRegistrar 2>/dev/null || true

echo "Installed: $TARGET"
file "$TARGET/Contents/MacOS/$PRODUCT"
echo "Validate with: auval -v aumu 2wvF Tmtt"
