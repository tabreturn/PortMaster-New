#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

# Locate PortMaster control folder
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

GAMEDIR=/$directory/ports/ambermoonnet
BINARY="Ambermoon.net"

# Redirect all output to log file
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

cd "$GAMEDIR"

# Extract binary from 7z archive on first run
if [ ! -f "$GAMEDIR/$BINARY" ]; then
  pm_message "Preparing files ..."
  "$controlfolder/7zzs.${DEVICE_ARCH}" x "$GAMEDIR/$BINARY.7z.001" -o"$GAMEDIR/"
  rm "$GAMEDIR/$BINARY.7z."*
  pm_message "Launching game ..."
fi

# Probe for native Mali EGL/GLES/SDL2 libraries across firmware variants.
# We bypass gl4es (which Westonpack provides for desktop GL games) and point
# SDL directly at the system GLES2 driver since Ambermoon.net uses GLES2 natively.
for p in /usr/lib64/libEGL.so /usr/lib/libEGL.so /usr/lib/libEGL.so.1 /usr/lib/aarch64-linux-gnu/libEGL.so.1; do
  [ -f "$p" ] && EGL_LIB="$p" && break
done
for p in /usr/lib64/libGLESv2.so /usr/lib/libGLESv2.so /usr/lib/libGLESv2.so.2 /usr/lib/aarch64-linux-gnu/libGLESv2.so.2; do
  [ -f "$p" ] && GLES_LIB="$p" && break
done
for p in /usr/lib64/libSDL2.so /usr/lib/libSDL2-2.0.so.0 /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0 /usr/lib/libSDL2-2.0.so; do
  [ -f "$p" ] && SDL2_LIB="$p" && break
done

export TEXTINPUTINTERACTIVE="Y"

$GPTOKEYB "$BINARY" -c "$GAMEDIR/$BINARY.gptk" &
pm_platform_helper "$GAMEDIR/$BINARY"

# Mount Westonpack to provide a headless X11/EGL compositor.
# Lazy-unmount first to clear any stale mount from a previous crashed session.
weston_dir="/tmp/westonpack"
$ESUDO mkdir -p "$weston_dir"
$ESUDO umount -l "$weston_dir" 2>/dev/null || true
$ESUDO mount "$controlfolder/libs/weston_pkg_0.2.squashfs" "$weston_dir"

$ESUDO env \
  WESTON_HEADLESS_WIDTH="$DISPLAY_WIDTH" \
  WESTON_HEADLESS_HEIGHT="$DISPLAY_HEIGHT" \
  SDL_AUDIODRIVER=alsa \
  LIBGL_ES=2 \
  SDL_VIDEO_X11_FORCE_EGL=1 \
  LIBGL_NOES2COMPAT=1 \
  SDL_VIDEO_EGL_DRIVER="$EGL_LIB" \
  SDL_VIDEO_GL_DRIVER="$GLES_LIB" \
  SDL2_LIBRARY="$SDL2_LIB" \
  "$weston_dir/westonwrap.sh" headless noop kiosk crusty_x11egl \
  ./"$BINARY"

$ESUDO umount "$weston_dir"

pm_finish
