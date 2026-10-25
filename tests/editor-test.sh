#!/bin/bash
# editor-test.sh : runs editor-test.ahk on a copy of editor-fixture.txt (a fixed layout, so the checks do not
# depend on your own layouts). The test moves the mic; your saved settings are put back afterwards.
. "$(dirname "$0")/env.sh"
cp "$T/editor-fixture.txt" "$T/editor-copy.txt"
cp "$T/editor-test.ahk" "$ROOT/zz-editor-test.ahk"
[ -f "$ROOT/touchdock.ini" ] && cp "$ROOT/touchdock.ini" "$T/ini-before.ini"
cd /mnt/c && timeout 90 "$AHK" /ErrorStdOut "$ROOTW\\zz-editor-test.ahk" 2>&1 | tr -d '\r'
rm -f "$ROOT/zz-editor-test.ahk" "$T"/editor-copy.*
[ -f "$T/ini-before.ini" ] && mv "$T/ini-before.ini" "$ROOT/touchdock.ini"
