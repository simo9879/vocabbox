#!/bin/sh
set -eu
BUNDLE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$BUNDLE_DIR/Godot" --main-pack "$BUNDLE_DIR/vocab-box.pck" "$@"
