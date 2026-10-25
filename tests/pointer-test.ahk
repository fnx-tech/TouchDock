#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; pointer-test.ahk : draws an arrow pointer of our own that follows the real pointer, to see whether it shows
; on the tablet over Remote Desktop. A small window with a "Close test" button ends it (or 10 minutes pass).
CoordMode("Mouse", "Screen")
s := A_ScreenDPI / 96 * 1.4
; The arrow: a black outline window with a white arrow window on top, both shaped by a polygon and click-through.
outer := [[0, 0], [0, 21], [5, 16], [9, 25], [13, 23], [9, 15], [16, 15]]
inner := [[1.5, 3.5], [1.5, 17.5], [5.5, 13.5], [9.6, 22], [11, 21.3], [7, 13.3], [12.3, 13.3]]
Shape(pts) {
    r := ""
    for p in pts
        r .= Round(p[1] * s) "-" Round(p[2] * s) " "
    return r
}
MakeArrow(color, pts) {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000020", "")  ; no-activate, click-through
    g.BackColor := color
    g.Show("x0 y0 w" Round(17 * s) " h" Round(26 * s) " NoActivate")
    WinSetTransparent(255, g)  ; layered, so clicks pass through to what is under it
    WinSetRegion(Shape(pts), g)
    return g
}
black := MakeArrow("000000", outer), white := MakeArrow("FFFFFF", inner)

C := Gui("+AlwaysOnTop +ToolWindow -DPIScale +E0x08000000", "Pointer test")
C.BackColor := "202020"
C.SetFont("s13 cWhite", "Segoe UI")
C.AddText("x16 y12 w380", "Use the touchpad tab: does an arrow follow?")
b := C.AddText("x16 y52 w380 h50 Center +0x200 Background7A2A2A", "Close test")
b.OnEvent("Click", (*) => ExitApp())
C.Show("x40 y40 w412 h116 NoActivate")
SetTimer(() => ExitApp(), -600000)  ; 10 minutes

lx := -1, ly := -1
SetTimer(Follow, 10)
Follow() {
    global lx, ly
    MouseGetPos(&x, &y)
    if (x = lx && y = ly)
        return
    lx := x, ly := y
    ; The arrow's tip sits exactly on the pointer's spot.
    black.Move(x, y), white.Move(x, y)
}
