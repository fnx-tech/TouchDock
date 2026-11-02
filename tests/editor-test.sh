#!/bin/bash
# editor-test.sh : runs editor-test.ahk on a copy of editor-fixture.txt (a fixed layout, so the checks do not
# depend on your own layouts). The test closes your running TouchDock (single instance), moves the mic and writes
# touchdock.ini; afterwards the ini is put back (or removed if there was none) and your TouchDock is started again.
. "$(dirname "$0")/env.sh"
procs() { (cd /mnt/c && powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$TW\\procs.ps1" | tr -d '\r'); }
if procs | grep -q 'zz-editor-test.ahk'; then echo "another editor-test is running"; exit 1; fi
was_running=0; procs | grep -q 'touchdock.ahk' && was_running=1
had_ini=0; [ -f "$ROOT/touchdock.ini" ] && { cp "$ROOT/touchdock.ini" "$T/ini-before.ini"; had_ini=1; }
cp "$T/editor-fixture.txt" "$T/editor-copy.txt"
cp "$T/editor-test.ahk" "$ROOT/zz-editor-test.ahk"
cd /mnt/c && timeout 90 "$AHK" /ErrorStdOut "$ROOTW\\zz-editor-test.ahk" 2>&1 | tr -d '\r'
rm -f "$ROOT/zz-editor-test.ahk" "$T"/editor-copy.*
if [ $had_ini = 1 ]; then mv "$T/ini-before.ini" "$ROOT/touchdock.ini"; else rm -f "$ROOT/touchdock.ini"; fi
[ $was_running = 1 ] && "$T/restart.sh"
