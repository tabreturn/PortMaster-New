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
GAMEDIR="/$directory/ports/desertchild"

# cd and set permissions
cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1
$ESUDO chmod +x $GAMEDIR/gmloadernext.aarch64

# exports
export LD_LIBRARY_PATH="/usr/lib:$GAMEDIR/lib:$GAMEDIR/lib:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# check if the patching needs to be applied
if [ ! -f "$GAMEDIR/patchlog.txt" ] && [ -f "$GAMEDIR/assets/data.win" ]; then
  if [ -f "$controlfolder/utils/patcher.txt" ]; then
    set -o pipefail
    export ESUDO
    export DEVICE_RAM
    export PATCHER_FILE="$GAMEDIR/tools/patchscript"
    export PATCHER_GAME="$(basename "${0%.*}")"
    export PATCHER_TIME="a few minutes"
    source "$controlfolder/utils/patcher.txt"
    $ESUDO umount "$DOTNETDIR"
  else
    pm_message "This port requires the latest version of PortMaster."
    pm_finish
    exit 1
  fi
fi


$GPTOKEYB "gmloadernext.aarch64" & #-c "___.gptk" &
pm_platform_helper "$GAMEDIR/gmloadernext.aarch64"
./gmloadernext.aarch64 -c "gmloader.json"

# cleanup
pm_finish
