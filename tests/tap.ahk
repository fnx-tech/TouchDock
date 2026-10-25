#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; tap.ahk <window title> <control text> [hold ms] [dx dy] : presses that control; with dx dy, slides by that much first.
CoordMode("Mouse", "Screen")
SetTimer(() => ExitApp(), -30000)
title := A_Args[1], text := A_Args[2]
hold := A_Args.Length >= 3 ? Integer(A_Args[3]) : 40
dx := A_Args.Length >= 5 ? Integer(A_Args[4]) : 0, dy := A_Args.Length >= 5 ? Integer(A_Args[5]) : 0
g := WinExist(title)
target := 0
for h in WinGetControlsHwnd(g)
    if (ControlGetText(h) = text || (text ~= "^[0-9A-F]{4}$" && ControlGetText(h) = Chr("0x" text)))
        target := h
if !target {
    FileAppend("no control '" text "'`n", "*")
    ExitApp(1)
}
WinGetPos(&gx, &gy, , , g)
ControlGetPos(&cx, &cy, &cw, &ch, target)
MouseGetPos(&ox, &oy)
x0 := gx + cx + cw // 2, y0 := gy + cy + ch // 2
MouseMove(x0, y0, 0)
Sleep(200)
SendEvent("{LButton down}")
if (dx || dy) {
    loop 10 {
        MouseMove(x0 + dx * A_Index // 10, y0 + dy * A_Index // 10, 0)
        Sleep(30)
    }
}
Sleep(hold)
SendEvent("{LButton up}")
Sleep(600)
MouseMove(ox, oy, 0)
FileAppend("pressed '" text "'`n", "*")
