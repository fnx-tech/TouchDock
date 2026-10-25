#!/bin/bash
# build.sh : builds dist/TouchDock.exe, dist/TouchDock-v<version>-portable.zip and dist/TouchDock-v<version>-setup.exe.
# Run from WSL on the Windows PC. Needs AutoHotkey v2 with Ahk2Exe, and Inno Setup 6 (both per-user installs).
set -e
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ROOTW=$(wslpath -w "$ROOT")
LAD=$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')")
LADW=$(wslpath -w "$LAD")
AHKDIR="$LAD/Programs/AutoHotkey"
ISCC="$LAD/Programs/Inno Setup 6/ISCC.exe"
[ -f "$ISCC" ] || ISCC="/mnt/c/Program Files (x86)/Inno Setup 6/ISCC.exe"
VERSION=$(sed -n 's/^#define AppVersion "\(.*\)"/\1/p' "$ROOT/installer/touchdock.iss" | tr -d '\r')
cd /mnt/c

# Only the three outputs are cleared; release-notes.md stays.
mkdir -p "$ROOT/dist"
rm -f "$ROOT/dist/TouchDock.exe" "$ROOT/dist/TouchDock-v$VERSION-portable.zip" "$ROOT/dist/TouchDock-v$VERSION-setup.exe"

"$AHKDIR/Compiler/Ahk2Exe.exe" /in "$ROOTW\\touchdock.ahk" /out "$ROOTW\\dist\\TouchDock.exe" \
  /base "$LADW\\Programs\\AutoHotkey\\v2\\AutoHotkey64.exe"
[ -f "$ROOT/dist/TouchDock.exe" ] || { echo "Ahk2Exe produced no exe" >&2; exit 1; }

# The empty "portable" file next to the exe tells it to keep its files in its own folder.
PT=$(mktemp -d)
cp "$ROOT/dist/TouchDock.exe" "$PT/"
: > "$PT/portable"
python3 - "$PT" "$ROOT/dist/TouchDock-v$VERSION-portable.zip" <<'PY'
import sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for n in ("TouchDock.exe", "portable"):
        z.write(src + "/" + n, n)
PY
rm -rf "$PT"

"$ISCC" "$ROOTW\\installer\\touchdock.iss"
ls -l "$ROOT/dist"
