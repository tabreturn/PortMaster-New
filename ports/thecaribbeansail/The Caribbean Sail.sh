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
export PORT_32BIT="Y"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Variables
GAMEDIR="/$directory/ports/thecaribbeansail"

# CD and set permissions
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
$ESUDO chmod +x -R $GAMEDIR/*

# Exports
export LD_LIBRARY_PATH="/usr/lib32:$GAMEDIR/lib:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# Display loading splash
$ESUDO ./tools/splash "splash.png" 2000

# Patch file
if [ -f "./gamedata/data.win" ]; then
  $controlfolder/xdelta3 -d -s "./gamedata/data.win" "./gamedata/patch.xdelta3" "./gamedata/game.droid"
  [ $? -eq 0 ] && rm "./gamedata/data.win" || pm_message "Patching of data.win has failed"
  rm -f gamedata/*.{dll,exe,win}
fi

# Assign configs and load the game
$GPTOKEYB "gmloader.aarch64" -c "thecaribbeansail.gptk" &
pm_platform_helper "gmloader.armhf"
./gmloader.armhf -c gmloader.json

# Cleanup
pm_finish
