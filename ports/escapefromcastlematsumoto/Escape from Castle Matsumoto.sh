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

GAMEDIR="/$directory/ports/escapefromcastlematsumoto"
BINARY=efcm

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# setup conf directory
$ESUDO rm -rf ~/.local/share/Escape\ From\ Castle\ Matsumoto
mkdir -p ~/.local/share
ln -sfv "$GAMEDIR/conf" ~/.local/share/Escape\ From\ Castle\ Matsumoto

cd $GAMEDIR

mv lib*.so* ./libs.aarch64
mv *.txt ./licenses

export LD_LIBRARY_PATH="$GAMEDIR/libs.aarch64:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

$GPTOKEYB "$BINARY" -c ./$BINARY.gptk &
pm_platform_helper "$GAMEDIR/$BINARY"
./$BINARY 
pm_finish
