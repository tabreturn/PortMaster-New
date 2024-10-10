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
# device_info.txt will be included by default

[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

export PORT_32BIT="Y"
GAMEDIR="/$directory/ports/self"

export LD_LIBRARY_PATH="/usr/lib32:$GAMEDIR/libs:$LD_LIBRARY_PATH"
export GMLOADER_DEPTH_DISABLE=1
export GMLOADER_SAVEDIR="$GAMEDIR/gamedata/"
export GMLOADER_PLATFORM="os_linux"

# We log the execution of the script into log.txt
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

cd $GAMEDIR

# Check if "data.win" exists and its MD5 checksum matches the specified value then apply patch
if [ -f "gamedata/data.win" ]; then
    $SUDO $controlfolder/xdelta3 -d -s "./gamedata/data.win" "./gamedata/patch.xdelta3" "./gamedata/data_patched.win"
    rm -r "./gamedata/data.win"
fi

# Check for file existence before trying to manipulate them:
[ -f "./gamedata/data_patched.win" ] && mv gamedata/data_patched.win gamedata/game.droid

$GPTOKEYB "gmloader" -c ./self.gptk &

$ESUDO chmod +x "$GAMEDIR/gmloader"
pm_platform_helper $GAMEDIR/gmloader
./gmloader game.apk

pm_finish
