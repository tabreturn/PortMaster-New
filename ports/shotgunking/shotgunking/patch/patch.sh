#!/bin/bash
# Patch Sugar engine Lua code in data.sgr for gamepad fixes.
# Called by launch script on first run.  Idempotent (skips if .patched exists).
set -e

GAMEDIR="$1"
SGR="$GAMEDIR/gamedata/shotgun_king.app/Contents/MacOS/data.sgr"
TOOLS="$GAMEDIR/tools"
PATCHES="$GAMEDIR/patch"
MARKER="$GAMEDIR/gamedata/.patched"

[ -f "$MARKER" ] && exit 0

# Backup original
cp "$SGR" "${SGR}.orig"

# Extract
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
"$TOOLS/sgr_extract" "$SGR" "$TMPDIR"

# Apply all .patch files
for p in "$PATCHES"/*.patch; do
    [ -f "$p" ] || continue
    echo "Applying $(basename "$p")..."
    patch -p1 -d "$TMPDIR" < "$p"
done

# Repack
"$TOOLS/sgr_repack" "$TMPDIR" "$SGR"

touch "$MARKER"
echo "Lua patches applied successfully"
