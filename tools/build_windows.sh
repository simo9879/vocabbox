#!/bin/sh
# Windows x86_64 prototype bundle plus one shareable zip, built from the
# installed official release export templates.
set -eu
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-godot}
OUT_DIR="$REPO_DIR/builds/windows"
ARCHIVE="$REPO_DIR/builds/vocab-box-windows-x86_64.zip"
SUM_FILE="$REPO_DIR/builds/SHA256SUMS"

# This GDScript project must be exported by a standard build, not the .NET one.
case "$("$GODOT_BIN" --version)" in
  *.mono.*)
    printf '%s\n' 'Use the standard Godot executable for this Windows export.' >&2
    exit 1
    ;;
esac

mkdir -p "$OUT_DIR"
"$GODOT_BIN" --headless --path "$REPO_DIR/vocab-box" --editor --import --quit

# Block the build on the model and route checks.
"$GODOT_BIN" --headless --path "$REPO_DIR/vocab-box" --script res://tests/test_runner.gd

"$GODOT_BIN" --headless --path "$REPO_DIR/vocab-box" --export-release 'Windows Desktop' "$OUT_DIR/vocab-box.exe"

# Notices, credits and player instructions travel with the executable.
"$GODOT_BIN" --headless --path "$REPO_DIR/vocab-box" --script res://tests/notices.gd -- "$OUT_DIR/GODOT-LICENSES.txt"
cp "$REPO_DIR/tools/windows-readme.txt" "$OUT_DIR/README.txt"
cp "$REPO_DIR/tools/run-with-speech.ps1" "$OUT_DIR/run-with-speech.ps1"
cp "$REPO_DIR/tools/run-with-speech.cmd" "$OUT_DIR/run-with-speech.cmd"
cp "$REPO_DIR/docs/asset-credits.md" "$OUT_DIR/ASSET-CREDITS.md"

# The exe and its .pck must stay side by side, so share them as one archive.
rm -f "$ARCHIVE"
(cd "$REPO_DIR/builds" && zip -q -r -1 "$ARCHIVE" windows)

# Keep the checksum list current without dropping other bundles.
{ grep -v "builds/vocab-box-windows-x86_64.zip" "$SUM_FILE" 2>/dev/null || true
  cd "$REPO_DIR" && sha256sum "builds/vocab-box-windows-x86_64.zip"
} > "$SUM_FILE.tmp"
mv "$SUM_FILE.tmp" "$SUM_FILE"

printf '%s\n' "Share $ARCHIVE"
