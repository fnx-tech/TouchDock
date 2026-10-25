#!/bin/bash
# restart.sh : restarts TouchDock (single instance: the new one replaces the old) and waits for it.
. "$(dirname "$0")/env.sh"
cd /mnt/c && ("$AHK" "$ROOTW\\touchdock.ahk" &) ; sleep 3
