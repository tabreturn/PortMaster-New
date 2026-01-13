#!/bin/bash

# portmaster preamble
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

# controls
source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# script variables
GAMEDIR="/$directory/ports/escapefromcastlematsumoto"
BINARY=efcm

# logs
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# setup conf directory
CONFDIR="$GAMEDIR/conf"
bind_directories "$HOME/.local/share/Escape From Castle Matsumoto" "$CONFDIR"

# exports
export LD_LIBRARY_PATH="$GAMEDIR/libs:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# run game
cd $GAMEDIR
$GPTOKEYB "$BINARY" -c ./$BINARY.gptk &
pm_platform_helper "$GAMEDIR/$BINARY"
./$BINARY

# clean up
pm_finish
