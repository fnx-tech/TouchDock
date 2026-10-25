#!/bin/bash
# env.sh : sourced by the other .sh test scripts (run them from WSL on the Windows PC that runs TouchDock).
# T = this tests folder, ROOT = the TouchDock folder (WSL paths); ROOTW / TW = the same as Windows paths.
# AHK = AutoHotkey v2; set AHK yourself if it is not in the usual per-user install folder.
T=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(dirname "$T")
ROOTW=$(wslpath -w "$ROOT")
TW=$(wslpath -w "$T")
if [ -z "$AHK" ]; then
  AHK=$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")/Programs/AutoHotkey/v2/AutoHotkey64.exe
fi
