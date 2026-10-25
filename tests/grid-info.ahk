#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; Prints where the grid and the mic are, and the controls' texts. Used by the layout-editor tests.
DetectHiddenWindows(true)
out := ""
for t in ["TouchDock Grid", "TouchDock ahk_class AutoHotkeyGUI", "TouchDock Editor"] {
    if !(h := WinExist(t)) {
        out .= t ": none`n"
        continue
    }
    WinGetPos(&x, &y, &w, &h2, h)
    out .= t ": " x "," y " " w "x" h2 (DllCall("IsWindowVisible", "Ptr", h) ? " visible" : " hidden") "`n"
}
FileAppend(out, "*")
