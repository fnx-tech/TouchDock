#!/bin/bash
# shots.sh <prefix> : screenshot of the grid in each layout (Edit, Keys, Shortcuts), then back to Edit.
. "$(dirname "$0")/env.sh"
D=$T/out; mkdir -p $D
for L in Keys Shortcuts Edit; do
  $T/run.sh tap.ahk "TouchDock Grid" "$L" >/dev/null; sleep 1
  read x y w h < <($T/run.sh grid-info.ahk | sed -n 's/^TouchDock Grid: \([0-9-]*\),\([0-9-]*\) \([0-9]*\)x\([0-9]*\).*/\1 \2 \3 \4/p')
  [ -z "$x" ] && { echo "grid not found"; exit 1; }
  cd /mnt/c && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$TW\\shot.ps1" $x $y $w $h "$TW\\out\\$1-$L.png"
  echo "$L: $x,$y ${w}x$h"
done
