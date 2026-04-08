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

GAMEDIR=/$directory/ports/ambermoonnet
BINARY="Ambermoon.net"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

#export LD_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}:$LD_LIBRARY_PATH"

export SDL_AUDIODRIVER=alsa
export LIBGL_ES=2

cd "$GAMEDIR"

if [ ! -f "$GAMEDIR/$BINARY" ]; then
  pm_message "Preparing files ..."
  "$controlfolder/7zzs.${DEVICE_ARCH}" x "$GAMEDIR/$BINARY.7z.001" -o"$GAMEDIR/"
  rm "$GAMEDIR/$BINARY.7z."*
  pm_message "Launching game ..."
fi

$GPTOKEYB "$BINARY" -c "$GAMEDIR/$BINARY.gptk" &
pm_platform_helper "$GAMEDIR/$BINARY"
./"$BINARY"
pm_finish
