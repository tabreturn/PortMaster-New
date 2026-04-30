#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

# preamble
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
GAMEDIR="/$directory/ports/flashlauncherpm"
CONFDIR="$GAMEDIR/conf"
mkdir -p "$CONFDIR"

# cd, logging
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# exports
export GAMEDIR
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"


# -----------------
# love2d menu phase
# -----------------

runtime="love_11.5"
if [ ! -f "$controlfolder/runtimes/${runtime}/love.txt" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the love_11.5 runtime. Please update PortMaster from https://portmaster.games/"
    sleep 5
    exit 1
  fi
  $ESUDO "$controlfolder/harbourmaster" --quiet --no-check runtime_check "${runtime}.squashfs"
fi
source "$controlfolder/runtimes/${runtime}/love.txt"

# run menu
rm -f /tmp/flash_selected_game
$GPTOKEYB "$LOVE_GPTK" &
pm_platform_helper "$LOVE_BINARY"
$LOVE_RUN "$GAMEDIR/menu"

# check if a game was selected
if [ ! -f /tmp/flash_selected_game ]; then
  echo "no game selected, exiting."
  pm_finish
  exit 0
fi
SELECTED_GAME=$(cat /tmp/flash_selected_game)
rm -f /tmp/flash_selected_game

# kill gptokeyb from menu phase
kill $(pidof gptokeyb) 2>/dev/null
sleep 0.3


# -----------------------
# weston + xcmflash phase
# -----------------------

game_executable="xcmFlash.ld"

# rename binary on first run and create ld-linux symlink in game dir
if [ -f "$GAMEDIR/xcmFlash" ] && [ ! -f "$GAMEDIR/xcmFlash.bin" ]; then
  mv "$GAMEDIR/xcmFlash" "$GAMEDIR/xcmFlash.bin"
fi
# copy ld-linux into gamedir so /proc/self/exe resolves to game dir
if [ ! -f "$GAMEDIR/$game_executable" ]; then
  cp "$GAMEDIR/libs/glibc/ld-linux-aarch64.so.1" "$GAMEDIR/$game_executable"
fi
chmod +x "$GAMEDIR/$game_executable"

# on rocknix, hide bundled libGL so gl4es can provide it
weston_libs="/tmp/weston/lib_aarch64/graphics/crusty_gbm/:/tmp/weston/lib_aarch64"
if [ "$CFW_NAME" = "ROCKNIX" ]; then
  mv "$GAMEDIR/libs/libGL.so.1" "$GAMEDIR/libs/libGL.so.1.disabled" 2>/dev/null
  crusty_libs="/tmp/weston/lib_aarch64/graphics/gl4es_glxpass/:/tmp/weston/lib_aarch64/graphics/crusty_glx/:/tmp/weston/lib_aarch64/graphics/crusty_x11egl/"
  game_libs="$crusty_libs:$GAMEDIR/libs/:$weston_libs:$LD_LIBRARY_PATH"
else
  game_libs="$GAMEDIR/libs/:$weston_libs:$LD_LIBRARY_PATH"
fi

# detect pulseaudio socket for audio passthrough
PULSE_SOCK=""
for p in /run/pulse/native /var/run/pulse/native /run/user/0/pulse/native /run/user/$(id -u)/pulse/native /tmp/pulse-*/native; do
  if [ -e "$p" ]; then
    PULSE_SOCK="$p"
    break
  fi
done
if [ -n "$PULSE_SOCK" ]; then
  export PULSE_SERVER="unix:$PULSE_SOCK"
fi

GAME_FOLDER=$(dirname "$SELECTED_GAME")
if [ -f "$GAME_FOLDER/controls.gptk" ]; then
  gptk_filename="$GAME_FOLDER/controls.gptk"
else
  gptk_filename="$GAMEDIR/flash.gptk"
fi

# weston setup
weston_dir=/tmp/weston
$ESUDO mkdir -p "${weston_dir}"
weston_runtime="weston_pkg_0.2"
if [ ! -f "$controlfolder/libs/${weston_runtime}.squashfs" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games/ for more info."
    sleep 5
    exit 1
  fi
  $ESUDO "$controlfolder/harbourmaster" --quiet --no-check runtime_check "${weston_runtime}.squashfs"
fi
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${weston_dir}" 2>/dev/null
fi
$ESUDO mount "$controlfolder/libs/${weston_runtime}.squashfs" "${weston_dir}"

# run swf
chmod +x "$GAMEDIR/$game_executable" "$GAMEDIR/xcmFlash.bin"
$GPTOKEYB "xcmFlash.bin" -c "$gptk_filename" &

if [ "$CFW_NAME" = "ROCKNIX" ]; then
  # reset cursor to top-left by injecting relative mouse events
  RESET_MOUSE_DATA=$'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'\
'\x02\x00\x00\x00\xf0\xd8\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00'\
'\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x01\x00\xf0\xd8\xff\xff'\
'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'\
'\x00\x00\x00\x00\x00\x00\x00\x00'
  (sleep 3 && printf '%s' "$RESET_MOUSE_DATA" > /dev/input/event3) 2>/dev/null &
  if [ "${CFW_GLIBC:-0}" -ge 234 ]; then
    $ESUDO env SDL_VIDEODRIVER=x11 CRUSTY_SHOW_CURSOR=0 WRAPPED_LIBRARY_PATH="$game_libs" PULSE_SERVER="$PULSE_SERVER" \
      $weston_dir/westonwrap.sh headless noop kiosk crusty_glx_gl4es \
      LD_PRELOAD= LD_LIBRARY_PATH="$game_libs" XDG_DATA_HOME="$CONFDIR" \
      "$GAMEDIR/xcmFlash.bin" "$SELECTED_GAME"
  else
    $ESUDO env SDL_VIDEODRIVER=x11 CRUSTY_SHOW_CURSOR=0 WRAPPED_LIBRARY_PATH="$game_libs" PULSE_SERVER="$PULSE_SERVER" \
      $weston_dir/westonwrap.sh headless noop kiosk crusty_glx_gl4es \
      LD_PRELOAD= LD_LIBRARY_PATH="$game_libs" XDG_DATA_HOME="$CONFDIR" \
      "$GAMEDIR/$game_executable" --argv0 "$GAMEDIR/xcmFlash" --library-path "$GAMEDIR/libs/glibc:$GAMEDIR/libs:$game_libs" "$GAMEDIR/xcmFlash.bin" "$SELECTED_GAME"
  fi
else
  if [ "${CFW_GLIBC:-0}" -ge 234 ]; then
    $ESUDO env CRUSTY_SHOW_CURSOR=1 WRAPPED_LIBRARY_PATH="$game_libs" PULSE_SERVER="$PULSE_SERVER" \
      $weston_dir/westonwrap.sh drm gl kiosk system \
      LD_PRELOAD= LD_LIBRARY_PATH="$game_libs" XDG_DATA_HOME="$CONFDIR" \
      "$GAMEDIR/xcmFlash.bin" "$SELECTED_GAME"
  else
    $ESUDO env CRUSTY_SHOW_CURSOR=1 WRAPPED_LIBRARY_PATH="$game_libs" PULSE_SERVER="$PULSE_SERVER" \
      $weston_dir/westonwrap.sh drm gl kiosk system \
      LD_PRELOAD= LD_LIBRARY_PATH="$game_libs" XDG_DATA_HOME="$CONFDIR" \
      "$GAMEDIR/$game_executable" --argv0 "$GAMEDIR/xcmFlash" --library-path "$GAMEDIR/libs/glibc:$GAMEDIR/libs:$game_libs" "$GAMEDIR/xcmFlash.bin" "$SELECTED_GAME"
  fi
fi

# clean up
mv "$GAMEDIR/libs/libGL.so.1.disabled" "$GAMEDIR/libs/libGL.so.1" 2>/dev/null
$ESUDO $weston_dir/westonwrap.sh cleanup
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${weston_dir}"
fi
pm_finish

