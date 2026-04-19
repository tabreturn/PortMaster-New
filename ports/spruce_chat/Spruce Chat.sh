#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/spruce_chat"
CONFDIR="$GAMEDIR/conf"

mkdir -p "$CONFDIR"
cd "$GAMEDIR"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

export XDG_DATA_HOME="$CONFDIR"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export SPRUCE_INPUT_MODE="sdl"

# SDL_GAMECONTROLLERCONFIG varies by CFW. chat.py has two independent
# swap knobs: SPRUCE_SWAP_AB (A/B pair) and SPRUCE_SWAP_XY (X/Y pair).
# Defaults (unset) = swap both, which matches Nintendo-labeled devices
# on positional CFWs.
#   muOS, ArkOS/dArkOS, ROCKNIX — fully label-based, disable both swaps.
#   unofficialOS — hybrid: A/B positional (keep swap), X/Y label-based
#     (disable XY swap only).
cfw_lower=$(printf '%s' "$CFW_NAME" | tr '[:upper:]' '[:lower:]')
echo "spruce: CFW_NAME='$CFW_NAME' (lower='$cfw_lower')"
case "$cfw_lower" in
  *muos*|*arkos*|*rocknix*)
    export SPRUCE_SWAP_AB=0 SPRUCE_SWAP_XY=0 ;;
  *unofficial*|*uos*)
    export SPRUCE_SWAP_XY=0 ;;
esac
if [ -d /opt/muos ] || [ -d /mnt/mmc/MUOS ] || [ -d /mnt/sdcard/MUOS ] \
   || [ -d /mnt/mmc/muos ] || [ -e /opt/muos/script/var/global/device.txt ]; then
  export SPRUCE_SWAP_AB=0 SPRUCE_SWAP_XY=0
fi
echo "spruce: SPRUCE_SWAP_AB=${SPRUCE_SWAP_AB:-1} SPRUCE_SWAP_XY=${SPRUCE_SWAP_XY:-1}"

# chat.py auto-detects screen dimensions via SDL_GetCurrentDisplayMode when
# SCREEN_WIDTH/SCREEN_HEIGHT aren't set. Export them here only to force a
# specific resolution (e.g. for debugging on a desktop).

# Bundled Python + SDL2 live inside the port
export PYTHONHOME="$GAMEDIR/python"
export PYTHONPATH="$GAMEDIR/python/lib/python3.11:$GAMEDIR/python/lib/python3.11/lib-dynload:$GAMEDIR/pysdl2"
export PYTHONDONTWRITEBYTECODE=1
export LD_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}:$GAMEDIR/python/lib:$LD_LIBRARY_PATH"
export PATH="$GAMEDIR/python/bin:$PATH"

# Don't set PYSDL2_DLL_PATH: forcing it to libs.aarch64 stops pysdl2 from
# falling back to the device's system libSDL2 (which we don't bundle, since
# focal's libSDL2 pulls in libXss/libwayland deps not present on most CFWs).
# pysdl2 still finds our bundled libSDL2_ttf via LD_LIBRARY_PATH above.

MODEL="$GAMEDIR/models/qwen2.5-0.5b-instruct-q4_0.gguf"

# Start llama-server in the background; chat.py shows a loading screen until it's ready
SERVER_PID=""
if [ -x "$GAMEDIR/llama-server" ] && [ -f "$MODEL" ]; then
  "$GAMEDIR/llama-server" \
    -m "$MODEL" \
    -c 1024 -t 4 -np 1 -ngl 0 -b 32 \
    --port 8086 --host 0.0.0.0 \
    > "$GAMEDIR/server.log" 2>&1 &
  SERVER_PID=$!
fi

# gptokeyb with no mapping acts as a process terminator on hotkey+start
$GPTOKEYB "python3.11" &

pm_platform_helper "$GAMEDIR/python/bin/python3.11"

"$GAMEDIR/python/bin/python3.11" "$GAMEDIR/chat.py"

if [ -n "$SERVER_PID" ]; then
  kill "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null
fi

pm_finish
