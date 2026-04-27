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

# pm
source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# variables
GAMEDIR="/$directory/ports/puzzlescriptpm"
CONFDIR="$GAMEDIR/conf/"

# cd & permissions
cd "$GAMEDIR"

# extract node binary on first run
if [ ! -f "$GAMEDIR/node" ]; then
  "$controlfolder/7zzs.$DEVICE_ARCH" x "$GAMEDIR/node.7z" -o"$GAMEDIR" -y
  chmod +x "$GAMEDIR/node"
  rm -f "$GAMEDIR/node.7z"
fi

# enable logging
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# exports
#export LD_LIBRARY_PATH="/usr/lib:$GAMEDIR/lib:$GAMEDIR/lib:$LD_LIBRARY_PATH"
#export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# suppress console text on framebuffer
printf "\033[?25l" > /dev/tty0 2>/dev/null
printf "\033[2J" > /dev/tty0 2>/dev/null
stty -echo < /dev/tty0 2>/dev/null

# run
$GPTOKEYB "node" -c "./inputs.gptk" &
pm_platform_helper "node"
./node ./pruntime-node/main.js ./games/

# restore console
stty echo < /dev/tty0 2>/dev/null
printf "\033[?25h" > /dev/tty0 2>/dev/null

# cleanup
pm_finish
