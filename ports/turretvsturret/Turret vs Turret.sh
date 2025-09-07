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

GAMEDIR=/$directory/ports/turretvsturret
CONFDIR="$GAMEDIR/conf/"

# ensure the conf directory exists
mkdir -p "$GAMEDIR/conf"

# set xdg environment variables for config & savefiles
export XDG_DATA_HOME="$CONFDIR"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

cd $GAMEDIR

# log execution of the script; script overwrites itself on each launch
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# load runtime
runtime="frt_3.5.2"
if [ ! -f "$controlfolder/libs/${runtime}.squashfs" ]; then
  # check for runtime if not downloaded via p.m
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
    sleep 5
    exit 1
  fi
  $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${runtime}.squashfs"
fi

# setup godot
godot_dir="$HOME/godot"
godot_file="$controlfolder/libs/${runtime}.squashfs"
$ESUDO mkdir -p "$godot_dir"
$ESUDO umount "$godot_file" || true
$ESUDO mount "$godot_file" "$godot_dir"
PATH="$godot_dir:$PATH"

export FRT_NO_EXIT_SHORTCUTS=FRT_NO_EXIT_SHORTCUTS
export CRUSTY_SHOW_CURSOR=1                   # enable cursor
export CRUSTY_CURSOR_FILE=$GAMEDIR/cursor.bmp # path to cursor file
export CRUSTY_CURSOR_OFFSET_X=0.5             # offset between pointer and sprite. 0 = top left; 1 = bottom right; 0.5 = middle
export CRUSTY_CURSOR_OFFSET_Y=0.5             # offset between pointer and sprite
export CRUSTY_CURSOR_SIZE=1.0                 # cursor size modifier. 1 = 100%, 2 = 200%, etc; do not use 0

$GPTOKEYB "$runtime" -c "./turretvsturret.gptk" &
pm_platform_helper "$runtime"
LD_PRELOAD="$GAMEDIR/lib/libcrusty.so" "$runtime" $GODOT_OPTS --main-pack "tvst.pck"

$ESUDO umount "$godot_dir"
pm_finish
