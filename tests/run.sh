#!/bin/bash
# run.sh <script.ahk> [args...] : runs a test script from this folder with AutoHotkey and prints its output.
. "$(dirname "$0")/env.sh"
s=$1; shift
cd /mnt/c && timeout 40 "$AHK" /ErrorStdOut "$TW\\$s" "$@" 2>&1 | tr -d '\r'
