#!/bin/bash
#
# Shotgun King install-time patch.
#
# Applies a small, idempotent mutation to code.lua inside data.sgr so the
# game's simulation tempo stays consistent with the developer's 60 Hz target
# on handhelds that render below that rate.
#
# Versioning: patch/version holds the current revision string. After a
# successful apply it's written to gamedata/.patched. On each run we:
#   1. If .patched matches $WANT_VERSION → nothing to do
#   2. Else, if $SGR.orig exists → restore it (covers partial previous runs
#      where .patched never got written)
#   3. Extract, mutate code.lua, repack, warm cache, stamp .patched
#
# The mutation uses awk landmark-matching and is idempotent — re-running
# against already-patched input is a no-op (we detect the sentinel comment
# and skip).
#
# Called by PortMaster's patcher.txt framework.

set -e

GAMEDIR="$(cd "$(dirname "$0")/.." && pwd)"
SGR="$GAMEDIR/gamedata/shotgun_king.app/Contents/MacOS/data.sgr"
TOOLS="$GAMEDIR/tools"
PATCHDIR="$GAMEDIR/patch"
TMPDIR="$GAMEDIR/.patch_tmp"
PATCHLOG="$GAMEDIR/patchlog.txt"
STAMP="$GAMEDIR/gamedata/.patched"

# Throttle dirty page cache to prevent FUSE OOM on devices like TrimUI Smart
# Pro: the kernel can buffer more dirty data than the FUSE daemon can flush,
# starving it of memory when we repack an 82 MB data.sgr back out. Must run
# BEFORE we open the tee-to-log pipe or start any I/O, or the FUSE backlog
# can deadlock the pipeline.
throttle_writes() {
    if [ -w /proc/sys/vm/dirty_ratio ]; then
        ORIG_DIRTY_RATIO=$(cat /proc/sys/vm/dirty_ratio)
        ORIG_DIRTY_BG_RATIO=$(cat /proc/sys/vm/dirty_background_ratio)
        echo 5 > /proc/sys/vm/dirty_ratio
        echo 3 > /proc/sys/vm/dirty_background_ratio
    fi
}

restore_writes() {
    if [ -n "$ORIG_DIRTY_RATIO" ] && [ -w /proc/sys/vm/dirty_ratio ]; then
        echo "$ORIG_DIRTY_RATIO" > /proc/sys/vm/dirty_ratio
        echo "$ORIG_DIRTY_BG_RATIO" > /proc/sys/vm/dirty_background_ratio
    fi
}

cleanup() {
    restore_writes
    rm -rf "$TMPDIR"
}
trap cleanup EXIT
# Kill the whole process group on signal so the tee subshell doesn't linger
# holding the log pipe open after a ctrl-C / launcher timeout.
trap 'kill 0 2>/dev/null; exit 1' HUP INT TERM

throttle_writes

> "$PATCHLOG"
# Only our own `echo` status lines go through tee → UI. Bulk tool output is
# redirected directly to the log file at each call site so we can't deadlock
# the pipeline if the FUSE daemon stalls mid-write.
exec > >(tee -a "$PATCHLOG") 2>&1

VERSION_FILE="$PATCHDIR/version"
if [ ! -f "$VERSION_FILE" ]; then
    echo "patch version file missing at $VERSION_FILE"
    exit 1
fi
WANT_VERSION="$(cat "$VERSION_FILE")"

if [ -f "$STAMP" ]; then
    HAVE_VERSION="$(cat "$STAMP")"
    if [ "$HAVE_VERSION" = "$WANT_VERSION" ]; then
        echo "Patch already applied (v$HAVE_VERSION)"
        exit 0
    fi
    echo "Patch out of date (have v$HAVE_VERSION, want v$WANT_VERSION) — refreshing"
fi

# Partial-install recovery: if a previous run moved the pristine .sgr aside
# but failed before stamping (e.g. warmup crashed), the current $SGR on disk
# is the ALREADY-PATCHED one. Restoring from .orig gets us back to pristine
# so we always patch from a known-good base.
if [ -f "$SGR.orig" ]; then
    echo "Restoring pristine data.sgr from backup"
    mv -f "$SGR.orig" "$SGR"
fi

if [ ! -f "$SGR" ]; then
    echo "Game data not found"
    exit 1
fi

echo "Preparing game data..."
rm -rf "$TMPDIR"
"$TOOLS/sgr_extract" "$SGR" "$TMPDIR" >>"$PATCHLOG" 2>&1

# ------------------------------------------------------------------
# Apply the auto-pace mutation to code.lua.
#
# The game's main update runs `lp()` (sim tick) a variable number of times
# based on the `fst` (fast) flag. At 60 fps render, fst=1 and sim tempo
# matches. Below 60 fps render, sim tempo slows visibly. We insert a small
# block that sets `fst` to round(dt * 60) capped at 5, so sim ticks scale
# with real elapsed time.
#
# Landmark: line `\tlocal fst=fast` (unique in code.lua). Insert the block
# immediately after it. Idempotent — skipped if the sentinel "AUTO-PACE" is
# already present.
# ------------------------------------------------------------------
echo "Applying patch..."
CODE="$TMPDIR/code.lua"
if grep -q "AUTO-PACE" "$CODE"; then
    echo "  code.lua already patched — skipping mutation"
else
    # code.lua ships with CRLF line endings (Windows-built). Strip \r up
    # front so the landmark regex matches on any awk (busybox/mawk/gawk);
    # Lua is line-ending-agnostic so emitting LF-only is fine.
    tr -d '\r' < "$CODE" | awk '
    {
        print
        if (!done && /^\tlocal fst=fast$/) {
            print ""
            print "\t-- AUTO-PACE: lp() is sim-only (no drawing), so when render fps drops"
            print "\t-- below 60 we run extra sim ticks to keep game tempo consistent with"
            print "\t-- the developer'"'"'s 60 Hz target. dt() returns real wall-clock seconds"
            print "\t-- since the last _update. dt*60 = how many 60 Hz ticks the last frame"
            print "\t-- covered; at 30 fps render that'"'"'s 2, at 20 fps it'"'"'s 3, etc."
            print "\t-- Capped at 5 to survive one-off hitches (GC pauses, loading stalls)"
            print "\t-- without spiraling."
            print "\tif not fst then"
            print "\t\tlocal want=flr(dt()*60+0.5)"
            print "\t\tif want>1 then fst=min(want,5) end"
            print "\tend"
            done = 1
        }
    }
    END {
        if (!done) {
            print "ERROR: landmark not found in code.lua" > "/dev/stderr"
            exit 1
        }
    }
    ' > "$CODE.new"
    mv "$CODE.new" "$CODE"
    # Post-check
    if ! grep -q "AUTO-PACE" "$CODE"; then
        echo "  auto-pace insert failed — landmark 'local fst=fast' not found"
        exit 1
    fi
fi

# Pre-seed the lang files into SDL's PrefPath. Sugar's file() stats the
# bundle path to confirm existence but then always opens from PrefPath —
# so every non-English lang file fails unless it's been copied there.
# safe_english.txt is the only one that's pre-populated by the engine
# itself, which is why English renders but nothing else does. Doing this
# at install time rather than game-launch time keeps the launcher lean.
PREFPATH="$GAMEDIR/userdata/PUNKCAKE Delicieux/Shotgun King - The Final Checkmate"
LANGDIR="$GAMEDIR/gamedata/shotgun_king.app/Contents/MacOS/lang"
if [ -d "$LANGDIR" ]; then
    mkdir -p "$PREFPATH/lang"
    cp -f "$LANGDIR"/*.txt "$PREFPATH/lang/" 2>>"$PATCHLOG"
fi

echo "Finalizing..."
"$TOOLS/sgr_repack" "$TMPDIR" "$SGR.new" >>"$PATCHLOG" 2>&1

mv "$SGR" "$SGR.orig"
mv "$SGR.new" "$SGR"

# Pre-populate the PCM cache so first real launch doesn't pay the OGG decode
# cost mid-boot. oggdec decodes each music file to raw S16 stereo PCM; the
# pcm_cache_write tool builds the SGPC cache file using per-file metadata
# (sample_t snapshot + expected pcm_bytes) from the shipped manifest — which
# was generated once on the dev host from a real engine-produced cache.
# Non-fatal on any failure: runtime fallback still decodes lazily.
CACHE_META="$PATCHDIR/cache_meta.txt"
CACHEDIR="$GAMEDIR/gamedata/shotgun_king.app/Contents/MacOS/.machismo-pcm-cache"
if [ -f "$CACHE_META" ] && [ -x "$TOOLS/oggdec" ] && [ -x "$TOOLS/pcm_cache_write" ]; then
    echo "Pre-populating audio cache..."
    mkdir -p "$CACHEDIR"
    warmed=0
    failed=0
    while read -r key freq pcm_bytes ogg_fn sample_t_hex; do
        case "$key" in '' | '#'*) continue ;; esac
        ogg_path="$TMPDIR/assets/music/$ogg_fn"
        out_path="$CACHEDIR/$key.pcm"
        if [ ! -f "$ogg_path" ]; then
            echo "  $ogg_fn: source missing, skipping" >>"$PATCHLOG"
            failed=$((failed + 1))
            continue
        fi
        if "$TOOLS/oggdec" --raw --quiet -o - "$ogg_path" 2>>"$PATCHLOG" |
           "$TOOLS/pcm_cache_write" "$out_path" "$freq" "$pcm_bytes" "$sample_t_hex" 2>>"$PATCHLOG"
        then
            warmed=$((warmed + 1))
        else
            echo "  $ogg_fn: build failed" >>"$PATCHLOG"
            failed=$((failed + 1))
        fi
    done < "$CACHE_META"
    if [ $failed -eq 0 ]; then
        echo "Audio cache populated ($warmed files)"
    else
        echo "Audio cache: $warmed ok, $failed failed — first boot of failed tracks will decode lazily"
    fi
else
    echo "Audio cache pre-population skipped (missing tool or manifest)"
fi

printf '%s' "$WANT_VERSION" > "$STAMP"
echo "Patch applied (v$WANT_VERSION)"
