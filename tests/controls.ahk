#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; controls.ahk [title] : prints the window's size and every control's text and rectangle (no screen needed).
DetectHiddenWindows(true)
title := A_Args.Length ? A_Args[1] : "TouchDock Grid"
g := WinExist(title)
if !g {
    FileAppend("no window`n", "*")
    ExitApp(1)
}
WinGetPos(, , &w, &h, g)
out := "window " w "x" h "`n"
for c in WinGetControlsHwnd(g) {
    ControlGetPos(&x, &y, &cw, &ch, c)
    t := ControlGetText(c)
    out .= (StrLen(t) = 1 && Ord(t) > 0xE000 ? Format("U+{:X}", Ord(t)) : t) " " x "," y " " cw "x" ch "`n"
}
WinGetPos(&mx, &my, &mw, &mh, "TouchDock ahk_class AutoHotkeyGUI")
WinGetPos(&gx, &gy, , , g)
FileAppend(out "mic at grid+" (mx - gx) "," (my - gy) " " mw "x" mh "`n", "*")
