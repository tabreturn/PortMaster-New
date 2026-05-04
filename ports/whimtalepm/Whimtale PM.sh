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
GAMEDIR="/$directory/ports/whimtalepm"
ROM="$GAMEDIR/runner.js"

# bind save data to port conf folder
bind_directories ~/.jsgamelauncher/whimtalepm $GAMEDIR/conf

# cd & logging
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# exports
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

# extract node binary on first run
if [ ! -f "$GAMEDIR/node" ]; then
  pm_message "Extracting node binary ..."
  if "$controlfolder/7zzs.$DEVICE_ARCH" x "$GAMEDIR/node.7z" -o"$GAMEDIR" -y; then
    chmod +x "$GAMEDIR/node"
    rm -f "$GAMEDIR/node.7z"
  else
    pm_message "extraction failed!"
    pm_finish
    exit 1
  fi
fi
# extract node_modules on first run
if [ ! -d "$GAMEDIR/node_modules" ]; then
  pm_message "Extracting node_modules ..."
  if "$controlfolder/7zzs.$DEVICE_ARCH" x "$GAMEDIR/node_modules.7z" -o"$GAMEDIR" -y; then
    rm -f "$GAMEDIR/node_modules.7z"
  else
    pm_message "extraction failed!"
    pm_finish
    exit 1
  fi
fi

# run
if [[ "$CFW_NAME" = "ROCKNIX" ]]; then
  export XDG_RUNTIME_DIR=/var/run/0-runtime-dir
  export WAYLAND_DISPLAY=wayland-1
  export SDL_VIDEODRIVER=wayland
  export SDL_APP_ID=jsgamelauncher
  export JSG_NO_EGL=1
  # override bundled sdl2 with system wayland-capable one
  if [ -f /usr/lib/libSDL2-2.0.so.0 ]; then
    export LD_PRELOAD=/usr/lib/libSDL2-2.0.so.0
  fi
  $GPTOKEYB "node" -c "$GAMEDIR/inputs.gptk" &
  pm_platform_helper "jsgamelauncher"
  ./node ./index.js -rom "$ROM" -fullscreen
else
  export JSG_NO_EGL=1
  SYSTEM_SDL2=$(ls /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.* 2>/dev/null | head -1)
  [ -n "$SYSTEM_SDL2" ] && export LD_PRELOAD="$SYSTEM_SDL2"
  $GPTOKEYB "node" -c "$GAMEDIR/inputs.gptk" &
  pm_platform_helper "node"
  ./node ./index.js -rom "$ROM" -fullscreen
fi

# cleanup
pm_finish

