#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; rect.ahk <margin> <title> [title...] : prints "x y w h" of the smallest box around those windows, plus a margin.
DetectHiddenWindows(false)
m := Integer(A_Args[1]), l := 99999, t := 99999, r := -99999, b := -99999
loop A_Args.Length - 1 {
    if !(h := WinExist(A_Args[A_Index + 1]))
        continue
    WinGetPos(&x, &y, &w, &hh, h)
    l := Min(l, x), t := Min(t, y), r := Max(r, x + w), b := Max(b, y + hh)
}
FileAppend((l - m) " " (t - m) " " (r - l + 2 * m) " " (b - t + 2 * m) "`n", "*")
