#!/bin/bash
# Evoland Legendary Edition PortMaster Patch Script
#
# Patches Evoland LE for handheld Linux devices:
#   1. Bytecode patching (GLES string fixes, steam stubs)
#   2. AOT compilation (hl2llvm → native binary)
#   3. Audio optimization (OGG downsample)
#   4. PAK repacking
#
# Called by PortMaster patcher UI.

set -e

# --- Paths ---

GAMEDIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$GAMEDIR/tools"
LIBS="$GAMEDIR/libs.aarch64"
GAMEDATA="$GAMEDIR/gamedata"
STATE="$GAMEDATA/.patch_state"
PATCHLOG="$GAMEDIR/patchlog.txt"

# Log everything (stdout + stderr) to patchlog while still showing on console
exec > >(tee -a "$PATCHLOG") 2>&1
> "$PATCHLOG"  # truncate at start

# Use tmpfs for intermediate files when available
if [ -d /dev/shm ]; then
    TMP="/dev/shm/el_patch_$$"
else
    TMP="$GAMEDATA/.patch_tmp"
fi
mkdir -p "$TMP"

cleanup() {
    rm -rf "$TMP"
}
trap cleanup EXIT
trap 'kill 0 2>/dev/null; exit 1' HUP INT TERM

# --- Version markers ---
# Bump these to force a step to re-run on devices with stale markers.

V_COMPILE="3"          # Step 2: el-patch-all + hl2llvm
V_PAK_EXTRACT="1"
V_OGG="1"
V_PAK_REPACK="1"

# --- Helpers ---

step_done() {
    local marker="$STATE/$1"
    [ -f "$marker" ] && [ "$(cat "$marker")" = "$2" ]
}

mark_done() {
    mkdir -p "$STATE"
    echo "$2" > "$STATE/$1"
}

fail() {
    echo "FATAL: $1"
    exit 1
}

# --- Step 1: Verify input files ---

echo "=== Evoland Legendary Edition Patcher ==="
echo ""

[ -f "$GAMEDATA/sdlboot.dat" ] || fail "sdlboot.dat not found in gamedata/"
[ -f "$GAMEDATA/evo1.pak" ] || fail "evo1.pak not found in gamedata/"
[ -f "$GAMEDATA/evo2.pak" ] || fail "evo2.pak not found in gamedata/"

echo "Game files found."

# --- Save language choice ---
# GAME_LANG is set by the patcher question UI (questions.lua)
if [ -n "$GAME_LANG" ]; then
    echo "$GAME_LANG" > "$GAMEDATA/.lang"
    echo "Language set to: $GAME_LANG"
fi

# --- Step 2: Bytecode patching + AOT compilation ---

if step_done "compile" "$V_COMPILE"; then
    echo "Step 2: Bytecode patching + compile... already done. OK"
else
    echo "Step 2: Bytecode patching..."

    # Backup original bytecode if not already backed up
    [ -f "$GAMEDATA/sdlboot.dat.orig" ] || cp "$GAMEDATA/sdlboot.dat" "$GAMEDATA/sdlboot.dat.orig"

    ORIG="$GAMEDATA/sdlboot.dat.orig"
    SUBSTITUTED="$TMP/evoland_substituted.hl"
    PATCHED="$TMP/evoland_patched.hl"

    # Phase 1: Haxe function substitution (GlDriver GLES constructor)
    "$TOOLS/hl-substitute" "$ORIG" "$TOOLS/el_patches.hl" -o "$SUBSTITUTED" \
        'h3d.impl.$GlDriver.__constructor__' \
        || fail "hl-substitute failed"

    # Phase 2: Bytecode patches (steam stubs, GLES string fixes)
    "$TOOLS/el-patch-all" "$SUBSTITUTED" "$PATCHED" \
        || fail "el-patch-all failed"

    # Save patched bytecode (also usable with HL interpreter for testing)
    cp "$PATCHED" "$GAMEDATA/sdlboot.dat"
    rm -f "$SUBSTITUTED"

    echo "Compiling game to native code..."
    echo "(This is the longest step — Evoland is a big game, please wait)"
    rm -rf "$TMP/evoland" "$TMP/evoland.d"

    OBJ_DIR="$TMP/evoland.d"

    # Run hl2llvm in background so we can monitor progress
    LD_LIBRARY_PATH="$LIBS:$LD_LIBRARY_PATH" \
    "$TOOLS/hl2llvm" \
        --batch -O3 \
        --inline-threshold=5000 \
        --fast-math \
        --mcpu=cortex-a35 \
        --threads=2 \
        --link \
        -L "$LIBS" \
        "$PATCHED" \
        -o "$TMP/evoland" >> "$PATCHLOG" 2>&1 &
    HL2LLVM_PID=$!

    # Monitor batch .o files for progress
    # ~67 batches estimated for Evoland (13347 functions / 200 per batch)
    EST_BATCHES=67
    LAST_COUNT=0
    while kill -0 $HL2LLVM_PID 2>/dev/null; do
        if [ -d "$OBJ_DIR" ]; then
            COUNT=$(ls "$OBJ_DIR"/batch.*.o 2>/dev/null | wc -l)
            if [ "$COUNT" -gt "$LAST_COUNT" ]; then
                PCT=$((COUNT * 90 / EST_BATCHES))
                [ "$PCT" -gt 90 ] && PCT=90
                echo "  Compiling... ${PCT}%"
                LAST_COUNT=$COUNT
            fi
        fi
        sleep 2
    done

    set +e
    wait $HL2LLVM_PID
    HL2LLVM_EXIT=$?
    set -e
    if [ $HL2LLVM_EXIT -ne 0 ]; then
        fail "hl2llvm compilation failed (exit code $HL2LLVM_EXIT)"
    fi

    chmod +x "$TMP/evoland"
    mv "$TMP/evoland" "$GAMEDATA/evoland"
    rm -rf "$TMP/evoland.d"
    rm -f "$PATCHED"

    mark_done "compile" "$V_COMPILE"
    echo "Step 2: Compile... OK"
fi

# --- Step 3: Unpack PAK files ---
# Evoland has 4 PAK files. We unpack them all for asset processing,
# then repack after optimization.

if step_done "pak_extract" "$V_PAK_EXTRACT"; then
    echo "Step 3: Unpack PAK files... already done. OK"
else
    echo "Step 3: Unpack PAK files..."

    for pak in evo1 evo1-extra evo2 evo2-extra; do
        PAKFILE="$GAMEDATA/${pak}.pak"
        [ -f "$PAKFILE" ] || continue

        # Backup original if not already backed up
        [ -f "$PAKFILE.orig" ] || cp "$PAKFILE" "$PAKFILE.orig"

        EXTRACTED="$GAMEDATA/${pak}_extracted"
        rm -rf "$EXTRACTED"
        "$TOOLS/hl-paktool" unpack "$PAKFILE.orig" -o "$EXTRACTED" \
            || fail "hl-paktool unpack ${pak}.pak failed"

        echo "  Unpacked ${pak}.pak"
    done

    mark_done "pak_extract" "$V_PAK_EXTRACT"
    echo "Step 3: Unpack PAK files... OK"
fi

# --- Step 4: Optimize audio (OGG downsample to 96kbps mono) ---

if step_done "ogg_done" "$V_OGG"; then
    echo "Step 4: Optimize audio... already done. OK"
else
    echo "Step 4: Optimize audio..."

    OGG_WORKLIST="$TMP/ogg_worklist.txt"
    > "$OGG_WORKLIST"
    for pak in evo1 evo1-extra evo2 evo2-extra; do
        EXTRACTED="$GAMEDATA/${pak}_extracted"
        [ -d "$EXTRACTED" ] || continue
        find "$EXTRACTED" -name "*.ogg" -type f -size +50k >> "$OGG_WORKLIST"
    done
    OGG_TOTAL=$(wc -l < "$OGG_WORKLIST")

    if [ "$OGG_TOTAL" -eq 0 ]; then
        echo "  No OGG files to optimize."
    else
        echo "  Optimizing $OGG_TOTAL audio files (96kbps mono)..."

        OGG_PROGRESS="$TMP/ogg_progress"
        OGG_FAILURES="$TMP/ogg_failures"
        echo 0 > "$OGG_PROGRESS"
        echo 0 > "$OGG_FAILURES"
        export OGG_PROGRESS OGG_FAILURES OGG_TOTAL PATCHLOG TOOLS LIBS

        ogg_worker() {
            local ogg="$1"
            local OK=0
            LD_LIBRARY_PATH="$LIBS:$LD_LIBRARY_PATH" \
            "$TOOLS/oggdec" -Q -o - "$ogg" 2>/dev/null | \
            LD_LIBRARY_PATH="$LIBS:$LD_LIBRARY_PATH" \
                "$TOOLS/oggenc" -Q -b 96 --downmix -o "$ogg.tmp" - 2>/dev/null
            if [ -f "$ogg.tmp" ] && [ -s "$ogg.tmp" ]; then
                mv "$ogg.tmp" "$ogg"
                OK=1
            else
                rm -f "$ogg.tmp"
                echo "OGG FAIL: $ogg" >> "$PATCHLOG"
            fi

            local COUNT PCT
            COUNT=$(cat "$OGG_PROGRESS")
            COUNT=$((COUNT + 1))
            echo "$COUNT" > "$OGG_PROGRESS"
            if [ "$OK" -eq 0 ]; then
                local FAILS
                FAILS=$(cat "$OGG_FAILURES")
                FAILS=$((FAILS + 1))
                echo "$FAILS" > "$OGG_FAILURES"
            fi
            PCT=$((COUNT * 100 / OGG_TOTAL))
            echo "  Optimizing audio... ${PCT}%"
        }
        export -f ogg_worker

        cat "$OGG_WORKLIST" | xargs -P 4 -I {} bash -c 'ogg_worker "$@"' _ {}

        OGG_FAIL_COUNT=$(cat "$OGG_FAILURES")
        rm -f "$OGG_WORKLIST" "$OGG_PROGRESS" "$OGG_FAILURES"

        if [ "$OGG_FAIL_COUNT" -gt 0 ]; then
            echo "  Warning: $OGG_FAIL_COUNT of $OGG_TOTAL files failed (kept originals)"
        fi

        echo "  Audio optimization complete."
    fi

    mark_done "ogg_done" "$V_OGG"
    echo "Step 4: Optimize audio... OK"
fi

# --- Step 5: Repack PAK files ---

if step_done "pak_repack" "$V_PAK_REPACK"; then
    echo "Step 5: Repack PAK files... already done. OK"
else
    echo "Step 5: Repack PAK files..."

    for pak in evo1 evo1-extra evo2 evo2-extra; do
        EXTRACTED="$GAMEDATA/${pak}_extracted"
        PAKFILE="$GAMEDATA/${pak}.pak"
        [ -d "$EXTRACTED" ] || continue

        "$TOOLS/hl-paktool" pack "$EXTRACTED" -o "$PAKFILE.tmp" \
            || fail "hl-paktool pack ${pak}.pak failed"
        mv "$PAKFILE.tmp" "$PAKFILE"

        # Clean up extracted files and original backup
        rm -rf "$EXTRACTED"
        rm -f "$PAKFILE.orig"

        echo "  Repacked ${pak}.pak"
    done

    mark_done "pak_repack" "$V_PAK_REPACK"
    echo "Step 5: Repack PAK files... OK"
fi

echo "2" > "$GAMEDATA/.patched_complete"

echo ""
echo "=== Patching complete ==="
