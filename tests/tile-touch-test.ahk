#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; tile-touch-test.ahk : presses the Down-arrow tile with a simulated finger (tap, then a 1.5 s hold) in a 200-line
; text box and checks how far the cursor went: a tap moves one line, a hold keeps repeating.
; Needs the mic button running with a layout that has the Down arrow, and the remote session connected.
CoordMode("Mouse", "Screen")
SetTimer(() => (FileAppend("timeout`n", "*"), ExitApp()), -30000)
Check(name, ok) => FileAppend((ok ? "ok    " : "FAIL  ") name "`n", "*")
t := ""
loop 200
    t .= A_Index "`n"
w := Gui(, "TileTouchTest")
e := w.AddEdit("w300 h200 -Wrap", t)
w.Show("x40 y40")
WinActivate("TileTouchTest"), e.Focus(), SendEvent("^{Home}"), Sleep(300)
g := WinExist("TouchDock Grid")
tile := 0
for h in WinGetControlsHwnd(g)
    if (ControlGetText(h) = Chr(0xE74B))
        tile := h
if !tile {
    FileAppend("no Down-arrow tile on the grid`n", "*")
    ExitApp(1)
}
WinGetPos(&gx, &gy, , , g)
ControlGetPos(&cx, &cy, &cw, &ch, tile)
px := gx + cx + cw // 2, py := gy + cy + ch // 2
DllCall("InitializeTouchInjection", "UInt", 1, "UInt", 3)
Touch(flags) {
    buf := Buffer(144, 0)
    NumPut("UInt", 2, buf, 0), NumPut("UInt", flags, buf, 12), NumPut("Int", px, buf, 32), NumPut("Int", py, buf, 36)
    DllCall("InjectTouchInput", "UInt", 1, "Ptr", buf)
}
Touch(0x10006), Sleep(30), Touch(0x40000), Sleep(600)
a := EditGetCurrentLine(e)
Check("tap moves one line (line " a ")", a = 2)
Touch(0x10006)
loop 30
    Sleep(50), Touch(0x20006)  ; a finger held still keeps reporting its spot
Touch(0x40000), Sleep(600)
b := EditGetCurrentLine(e)
Check("1.5 s hold keeps repeating (" b - a " more lines)", b - a > 10)
ExitApp()
