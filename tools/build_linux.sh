#!/bin/sh
# Portable Linux bundle; no export-template download required.
set -eu
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-godot}
# The portable bundle copies one engine binary; use the standard build for this GDScript project.
case "$("$GODOT_BIN" --version)" in
  *.mono.*)
    printf '%s\n' 'Use the standard Godot executable for this portable bundle.' >&2
    exit 1
    ;;
esac
mkdir -p "$REPO_DIR/builds/linux"
"$GODOT_BIN" --headless --path "$REPO_DIR/vocab-box" --editor --import --quit
"$GODOT_BIN" --headless --path "$REPO_DIR/vocab-box" --script res://tests/test_runner.gd
"$GODOT_BIN" --headless --path "$REPO_DIR/vocab-box" --export-pack 'Linux Desktop' "$REPO_DIR/builds/linux/vocab-box.pck"
"$GODOT_BIN" --headless --path "$REPO_DIR/vocab-box" --script res://tests/notices.gd
cp "$(command -v "$GODOT_BIN")" "$REPO_DIR/builds/linux/Godot"
cp "$REPO_DIR/tools/linux-launcher.sh" "$REPO_DIR/builds/linux/play.sh"
cp "$REPO_DIR/tools/linux-readme.txt" "$REPO_DIR/builds/linux/README.txt"
cp "$REPO_DIR/docs/asset-credits.md" "$REPO_DIR/builds/linux/ASSET-CREDITS.md"
chmod +x "$REPO_DIR/builds/linux/Godot" "$REPO_DIR/builds/linux/play.sh"
printf '%s\n' "Run $REPO_DIR/builds/linux/play.sh"
