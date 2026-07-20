#!/bin/bash
# Package the premake-built AU binary into a proper .component and install it.
# Usage: package_au.sh [configuration] [install-directory]
# A system-wide install usually requires: sudo package_au.sh Release /Library/Audio/Plug-Ins/Components
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-Debug}"
INSTALL_DIR="${2:-$HOME/Library/Audio/Plug-Ins/Components}"
BIN_DIR="$ROOT/build/xcode4/bin/x64/$CONFIG"
# Premake may emit either name depending on PRODUCT_NAME settings
if [[ -f "$BIN_DIR/RetroPlug" ]]; then
  BIN="$BIN_DIR/RetroPlug"
elif [[ -f "$BIN_DIR/RetroPlug_auv2_x64" ]]; then
  BIN="$BIN_DIR/RetroPlug_auv2_x64"
else
  echo "error: AU binary not found under $BIN_DIR" >&2
  ls -la "$BIN_DIR" >&2 || true
  exit 1
fi

DEST="$BIN_DIR/RetroPlug.component"
echo "Packaging $BIN -> $DEST"

rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"
cp "$BIN" "$DEST/Contents/MacOS/RetroPlug"
chmod +x "$DEST/Contents/MacOS/RetroPlug"
cp "$ROOT/resources/RetroPlug-AU-Info.plist" "$DEST/Contents/Info.plist"
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
TARGET="$INSTALL_DIR/RetroPlug.component"
STAGING="$INSTALL_DIR/.RetroPlug.component.install.$$"
BACKUP="$INSTALL_DIR/.RetroPlug.component.previous.$$"

# Finish the copy before moving the existing component out of the way. Both
# renames then occur on the destination filesystem and can be rolled back.
rm -rf "$STAGING" "$BACKUP"
cp -R "$DEST" "$STAGING"
if [[ -e "$TARGET" ]]; then
  mv "$TARGET" "$BACKUP"
fi
if ! mv "$STAGING" "$TARGET"; then
  if [[ -e "$BACKUP" ]]; then
    mv "$BACKUP" "$TARGET"
  fi
  exit 1
fi
rm -rf "$BACKUP"
killall -9 AudioComponentRegistrar 2>/dev/null || true

echo "Installed: $INSTALL_DIR/RetroPlug.component"
file "$INSTALL_DIR/RetroPlug.component/Contents/MacOS/RetroPlug"
echo "Validate with: auval -v aumu 2wvF Tmtt"
