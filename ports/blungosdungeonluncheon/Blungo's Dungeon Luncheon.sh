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

# variables
GAMEDIR="/$directory/ports/blungosdungeonluncheon"
GMLOADER_JSON="$GAMEDIR/gmloader.json"

# cd and set permissions
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# exports
export LD_LIBRARY_PATH="/usr/lib:$GAMEDIR/lib:$GAMEDIR/lib:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
$ESUDO chmod +x $GAMEDIR/gmloadernext.aarch64

# prepare game files
#if [ -f ./assets/data.win ]; then
#  mv "./assets/data.win" "./assets/game.droid"
#  zip -r -0 ./blungosdungeonluncheon.port ./assets/
#  rm -Rf ./assets/
#fi

# exports
export LD_LIBRARY_PATH="/usr/lib:$GAMEDIR/lib:$GAMEDIR/libs:$LD_LIBRARY_PATH"
export PATCHER_FILE="$GAMEDIR/tools/patchscript"
export PATCHER_GAME="Blungo's Dungeon Luncheon"
export PATCHER_TIME="less that a minute"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# check if install_completed to skip patching
if [ ! -f install_completed ]; then
  if [ -f "$controlfolder/utils/patcher.txt" ]; then
    source "$controlfolder/utils/patcher.txt"
    $ESUDO kill -9 $(pidof gptokeyb)
  else
    pm_message "This port requires the latest version of PortMaster."
    exit 1  # exit to prevent further execution
  fi
else
  pm_message "Patching process already completed. Skipping."
fi

# assign configs and load the game
$GPTOKEYB "gmloadernext.aarch64" -c "blungosdungeonluncheon.gptk" &
pm_platform_helper "$GAMEDIR/gmloadernext.aarch64"
./gmloadernext.aarch64 -c "$GMLOADER_JSON"

# cleanup
pm_finish
