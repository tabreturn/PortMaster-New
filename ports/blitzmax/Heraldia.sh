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
source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR=/$directory/ports/heraldia
game_executable="heraldia"
#game_libs=$GAMEDIR/libs.${DEVICE_ARCH}/:$LD_LIBRARY_PATH
x11sdl_path="$GAMEDIR/x11sdllib/"

# logging
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# mount Weston runtime
weston_dir=/tmp/weston
$ESUDO mkdir -p "${weston_dir}"
weston_runtime="weston_pkg_0.2"
if [ ! -f "$controlfolder/libs/${weston_runtime}.squashfs" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
    sleep 5
    exit 1
  fi
  $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${weston_runtime}.squashfs"
fi
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${weston_dir}"
fi
$ESUDO mount "$controlfolder/libs/${weston_runtime}.squashfs" "${weston_dir}"

cd $GAMEDIR

$GPTOKEYB2 "$game_executable" -c "$GAMEDIR/${game_executable}.ini" &
# start westonpack
$ESUDO env WRAPPED_LIBRARY_PATH_MALI="$x11sdl_path" WRAPPED_PRELOAD_MALI="$x11sdl_path/libSDL2-2.0.so.0" \
SDL_VIDEO_X11_FORCE_EGL=1 WRAPPED_LIBRARY_PATH=$game_libs \
$weston_dir/westonwrap.sh headless noop kiosk crusty_x11egl \
WAYLAND_DISPLAY= $GAMEDIR/$game_executable

# clean up
$ESUDO $weston_dir/westonwrap.sh cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${weston_dir}"
fi
pm_finish
