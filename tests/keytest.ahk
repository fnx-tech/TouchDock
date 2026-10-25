#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; keytest.ahk <control text or 4-hex glyph> <hold ms> : opens a 200-line text box at line 1, presses the tile,
; prints the line the cursor ends on and the text in the box's first line.
CoordMode("Mouse", "Screen")
SetTimer(() => (FileAppend("timeout`n", "*"), ExitApp()), -20000)
t := ""
loop 200
    t .= A_Index "`n"
w := Gui(, "KeyTest")
e := w.AddEdit("w300 h200 -Wrap", t)
w.Show("x40 y40")
WinActivate("KeyTest")
e.Focus()
SendEvent("^{Home}")
Sleep(300)
text := A_Args[1], hold := Integer(A_Args[2])
g := WinExist("TouchDock Grid")
for h in WinGetControlsHwnd(g)
    if (ControlGetText(h) = text || (text ~= "^[0-9A-F]{4}$" && ControlGetText(h) = Chr("0x" text)))
        tile := h
WinGetPos(&gx, &gy, , , g)
ControlGetPos(&cx, &cy, &cw, &ch, tile)
MouseGetPos(&ox, &oy)
MouseMove(gx + cx + cw // 2, gy + cy + ch // 2, 0)
SendEvent("{LButton down}")
Sleep(hold)
SendEvent("{LButton up}")
Sleep(500)
MouseMove(ox, oy, 0)
FileAppend("line " EditGetCurrentLine(e) "; first line: " StrSplit(e.Value, "`n")[1] "`n", "*")
ExitApp()
