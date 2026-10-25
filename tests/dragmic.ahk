#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; dragmic.ahk : drags the mic 60 px up-left and back; prints the mic and grid positions.
CoordMode("Mouse", "Screen")
SetTimer(() => ExitApp(), -20000)
DetectHiddenWindows(true)
MouseGetPos(&ox, &oy)
WinGetPos(&x, &y, &w, &h, "TouchDock ahk_class AutoHotkeyGUI")
WinGetPos(&gx, &gy, , , "TouchDock Grid")
SetDefaultMouseSpeed(10)
MouseClickDrag("L", x + w//2, y + h//2, x + w//2 - 60, y + h//2 - 60)
Sleep(500)
WinGetPos(&x2, &y2, , , "TouchDock ahk_class AutoHotkeyGUI")
WinGetPos(&gx2, &gy2, , , "TouchDock Grid")
FileAppend("mic " x "," y " -> " x2 "," y2 "   grid " gx "," gy " -> " gx2 "," gy2 "`n", "*")
MouseClickDrag("L", x2 + w//2, y2 + h//2, x + w//2, y + h//2)
MouseMove(ox, oy, 0)
