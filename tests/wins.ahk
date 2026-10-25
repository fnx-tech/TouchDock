#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; wins.ahk : lists visible AutoHotkey windows with their text, to spot error dialogs.
for hw in WinGetList("ahk_exe AutoHotkey64.exe") {
    t := ""
    try t := WinGetText(hw)
    FileAppend(hw " [" WinGetClass(hw) "] '" WinGetTitle(hw) "' " SubStr(StrReplace(t, "`r`n", " / "), 1, 300) "`n", "*")
}
