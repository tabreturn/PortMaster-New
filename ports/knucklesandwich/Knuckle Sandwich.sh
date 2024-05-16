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
source $controlfolder/device_info.txt
export PORT_32BIT="Y"

get_controls
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

$ESUDO chmod 666 /dev/tty0

GAMEDIR="/$directory/ports/knucklesandwich"

export LD_LIBRARY_PATH="/usr/lib32:$GAMEDIR/libs:$GAMEDIR/utils/libs"
export GMLOADER_DEPTH_DISABLE=1
export GMLOADER_SAVEDIR="$GAMEDIR/gamedata/"

# log the execution of the script into log.txt
exec > >(tee "$GAMEDIR/log.txt") 2>&1

cd $GAMEDIR

# check for and extract knucklesandwich.exe
if [ -f "knucklesandwich.exe" ]; then
    mkdir gamedata
    7z x knucklesandwich.exe -ogamedata -r

    # patch game.droid
    $controlfolder/xdelta3 -d -s "gamedata/data.win" "knucklesandwich.xdelta3" "gamedata/game.droid"
    rm "gamedata/data.win"

    # prepare to bundle assets
    mkdir -p ./assets
    mv ./gamedata/*.ogg ./assets/ || exit 1
    mv ./gamedata/*.dat ./assets/ || exit 1

    # zip the contents of ./game.apk including the .ogg and .dat files
    zip -r -0 ./knucklesandwich.apk ./assets/ || exit 1
    rm -Rf "$GAMEDIR/assets/" || exit 1

    # rename and move frames/temp/textures assets
    cd gamedata
    mkdir -p frames temp textures
    for file in frames@*; do
        mv "$file" "frames/${file/frames@/}"
    done
    for file in temp@*; do
        mv "$file" "temp/${file/temp@/}"
    done
    for file in textures@*; do
        mv "$file" "textures/${file/textures@/}"
    done
    cd ..

    # delete unnecessary files
    rm ./gamedata/*.exe ./gamedata/*.dll
    rm knucklesandwich.exe
fi

# ensure uinput is accessible so we can make use of the gptokeyb controls
$ESUDO chmod 666 /dev/uinput

$GPTOKEYB "gmloader" -c ./knucklesandwich.gptk &

$ESUDO chmod +x "$GAMEDIR/gmloader"

./gmloader knucklesandwich.apk

$ESUDO kill -9 $(pidof gptokeyb)
$ESUDO systemctl restart oga_events &
printf "\033c" > /dev/tty0

