#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; setini.ahk <section> <key> <value> : changes touchdock.ini.
IniWrite(A_Args[3], A_ScriptDir "\..\touchdock.ini", A_Args[1], A_Args[2])
