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

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# path variables
GAMEDIR="/${directory}/ports/ambermoonnet"
game_executable="Ambermoon.net"
gptk_filename="${game_executable}.gptk"

# logging
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# cd to gamedir and activate text input
cd "$GAMEDIR"
export TEXTINPUTINTERACTIVE="Y"

# extract binary from 7z archive on first run
if [ ! -f "$GAMEDIR/${game_executable}" ]; then
  pm_message "Preparing files ..."
  "$controlfolder/7zzs.${DEVICE_ARCH}" x "$GAMEDIR/${game_executable}.7z.001" -o"$GAMEDIR/"
  rm "$GAMEDIR/${game_executable}.7z."*
  pm_message "Launching game ..."
fi

# mount weston runtime
weston_dir="/tmp/weston"
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

# probe native amberelec/arkos/rocknix libraries
#if [[ "$CFW_NAME" = "AmberELEC" || "$CFW_NAME" = *"ArkOS"* || "$CFW_NAME" = "ROCKNIX"]]; then
  for p in /usr/lib64/libEGL.so /usr/lib/libEGL.so /usr/lib/libEGL.so.1 /usr/lib/aarch64-linux-gnu/libEGL.so.1; 
  do [ -f "$p" ] && EGL_LIB="$p" && break; done
  for p in /usr/lib64/libGLESv2.so /usr/lib/libGLESv2.so /usr/lib/libGLESv2.so.2 /usr/lib/aarch64-linux-gnu/libGLESv2.so.2; 
  do [ -f "$p" ] && GLES_LIB="$p" && break; done
  for p in /usr/lib64/libSDL2.so /usr/lib/libSDL2-2.0.so.0 /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0 /usr/lib/libSDL2-2.0.so; 
  do [ -f "$p" ] && SDL2_LIB="$p" && break; done
#fi

# check for rocknix ...
if [[ "$CFW_NAME" = "ROCKNIX" ]]; then
  # display message and exit if libmali
  if ! glxinfo | grep "OpenGL version string" >/dev/null; then
    pm_message "This Port does not support the libMali graphics driver. Switch to Panfrost to continue."
    sleep 5
    exit 1
  fi
fi

# load gptk (input config)
$GPTOKEYB "${game_executable}" -c "$GAMEDIR/${game_executable}.gptk" &
# start westonpack
$ESUDO env \
# put CRUSTY_SHOW_CURSOR=1 after "env" if you need a mouse cursor
#  WESTON_HEADLESS_WIDTH="$DISPLAY_WIDTH" \
#  WESTON_HEADLESS_HEIGHT="$DISPLAY_HEIGHT" \
#  DISPLAY_WIDTH="$DISPLAY_WIDTH" \
#  DISPLAY_HEIGHT="$DISPLAY_HEIGHT" \
#  SDL_AUDIODRIVER=alsa \
#  LIBGL_ES=2 \
  SDL_VIDEO_X11_FORCE_EGL=1 \
  LIBGL_NOES2COMPAT=1 \
  SDL_VIDEO_EGL_DRIVER="$EGL_LIB" \
  SDL_VIDEO_GL_DRIVER="$GLES_LIB" \
  SDL2_LIBRARY="$SDL2_LIB" \
  "$weston_dir/westonwrap.sh" headless noop kiosk crusty_x11egl \
  ./"${game_executable}"

# clean up
$ESUDO $weston_dir/westonwrap.sh cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${weston_dir}"
fi
pm_finish
