#!/bin/bash
# PORTMASTER: UnLevel, UnLevel

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

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

get_controls

GAMEDIR="/$directory/ports/unlevel"
CONFDIR="$GAMEDIR/conf"

mkdir -p "$CONFDIR/love"
cd "$GAMEDIR"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Verify the love_11.5 runtime is available; prompt the user to update PortMaster if not
runtime="love_11.5"
if [ ! -f "$controlfolder/runtimes/${runtime}/love.txt" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the love_11.5 runtime. Please update PortMaster from https://portmaster.games/"
    sleep 5
    exit 1
  fi
  $ESUDO "$controlfolder/harbourmaster" --quiet --no-check runtime_check "${runtime}.squashfs"
fi

# Redirect save / config data into the port's conf folder
export XDG_DATA_HOME="$CONFDIR"
bind_directories ~/.local/share/love "$CONFDIR/love"

export LD_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# Load the LÖVE 11.5 runtime (sets $LOVE_BINARY, $LOVE_RUN, $LOVE_GPTK)
source "$controlfolder/runtimes/${runtime}/love.txt"

# gptokeyb acts as a kill-switch / hotkey helper; LÖVE handles SDL input natively
$GPTOKEYB "$LOVE_GPTK" -c "./UnLevel.gptk" &

pm_platform_helper "$LOVE_BINARY"

$LOVE_RUN "$GAMEDIR/unlevel/gamedata.love"

pm_finish
