#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; pad-test.ahk : drives the grid's touchpad with simulated touches (Windows touch injection) and checks
; pointer movement, tap = click, two-finger tap and hold = right click, tap then slide = drag.
; Needs the mic button running with the Touchpad layout shown, and the remote session connected.
CoordMode("Mouse", "Screen")
SetTimer(() => (FileAppend("timeout`n", "*"), ExitApp()), -60000)
Check(name, ok) => FileAppend((ok ? "ok    " : "FAIL  ") name "`n", "*")

g := WinExist("TouchDock Grid")
pad := 0
for h in WinGetControlsHwnd(g)
    if (ControlGetText(h) = "Touchpad")
        pad := h
if !pad {
    FileAppend("no touchpad on the grid`n", "*")
    ExitApp(1)
}
WinGetPos(&gx, &gy, , , g)
ControlGetPos(&cx, &cy, &cw, &ch, pad)
px := gx + cx + cw // 2, py := gy + cy + ch // 2   ; centre of the pad

; A test window with a target: logs left and right clicks and drags.
T := Gui("+AlwaysOnTop +ToolWindow", "Pad target")
T.SetFont("s12")
tgt := T.AddText("x0 y0 w300 h200 Center +0x200 +0x100 BackgroundCCCCCC", "target")
T.Show("x60 y60 w300 h200 NoActivate")
clicks := 0, rclicks := 0, downs := 0
OnMessage(0x202, Counted), OnMessage(0x205, Counted), OnMessage(0x201, Counted), OnMessage(0x203, Counted)
Counted(w, l, m, h) {
    global clicks, rclicks, downs
    if (h != tgt.Hwnd && h != T.Hwnd)
        return
    (m = 0x202) ? clicks++ : (m = 0x205) ? rclicks++ : downs++
}

DllCall("InitializeTouchInjection", "UInt", 2, "UInt", 3)
Touch(fingers, flags) {  ; fingers: [[id, x, y], ...]
    n := fingers.Length, size := 144
    buf := Buffer(n * size, 0)
    for i, f in fingers {
        o := (i - 1) * size
        NumPut("UInt", 2, buf, o)            ; PT_TOUCH
        NumPut("UInt", f[1], buf, o + 4)     ; pointer id
        NumPut("UInt", flags, buf, o + 12)
        NumPut("Int", f[2], buf, o + 32), NumPut("Int", f[3], buf, o + 36)
    }
    return DllCall("InjectTouchInput", "UInt", n, "Ptr", buf)
}
DOWN := 0x10000 | 6, MOVE := 0x20000 | 6, UP := 0x40000
Slide(dx, dy, steps := 10) {
    Touch([[0, px, py]], DOWN), Sleep(30)
    loop steps
        Touch([[0, px + dx * A_Index // steps, py + dy * A_Index // steps]], MOVE), Sleep(20)
    Touch([[0, px + dx, py + dy]], UP), Sleep(150)
}
Tap() => (Touch([[0, px, py]], DOWN), Sleep(30), Touch([[0, px, py]], UP), Sleep(150))

; 1. slide moves the pointer by the slide times the speed, and the pointer does not jump to the finger
MouseMove(100, 700, 0), Sleep(100)  ; far left, so a slide never ends on the pad itself
Slide(100, 0)
MouseGetPos(&x1, &y1)
Check("slide 100 px right moves the pointer right (" x1 - 100 " px, y " y1 "), not to the pad", x1 > 150 && Abs(y1 - 700) < 20 && !(x1 >= gx + cx && x1 < gx + cx + cw && y1 >= gy + cy && y1 < gy + cy + ch))
DetectHiddenWindows(false)
Sleep(100)
arrowOk := false
if (a := WinExist("TouchDock Pointer")) {
    WinGetPos(&ax, &ay, , , a)
    arrowOk := Abs(ax - x1) <= 2 && Abs(ay - y1) <= 2
}
Check("drawn arrow shows at the pointer", arrowOk)
Sleep(3500)
Check("drawn arrow hides 3 s after the pad", !WinExist("TouchDock Pointer"))

; 2. tap = left click where the pointer is
MouseMove(200, 150, 0), Sleep(400)
MouseGetPos(&tx, &ty, &tw)
FileAppend("  before tap: pointer " tx "," ty " over '" WinGetTitle(tw) "'`n", "*")
Tap(), Sleep(300)
Check("tap clicks the target under the pointer (" clicks ")", clicks = 1)

; 3. two-finger tap = right click
Sleep(400)
Touch([[0, px, py], [1, px + 40, py]], DOWN), Sleep(30), Touch([[0, px, py], [1, px + 40, py]], UP), Sleep(300)
Check("two-finger tap right-clicks (" rclicks ")", rclicks = 1)

; 4. hold still 0.8 s = right click (a real finger keeps reporting its spot while held, so this does too)
Touch([[0, px, py]], DOWN)
loop 16
    Sleep(50), Touch([[0, px, py]], MOVE)
Touch([[0, px, py]], UP), Sleep(300)
Check("touch and hold right-clicks (" rclicks ")", rclicks = 2)

; 5. tap, then touch again and slide = button held while moving (the second press arrives as a double-click)
Sleep(400), MouseMove(150, 120, 0), Sleep(100)
d0 := downs, c0 := clicks
Tap(), Sleep(100)
Slide(30, 20, 5)
MouseGetPos(&x2, &y2)
Check("tap then slide drags (downs " downs - d0 ", pointer moved " x2 - 150 "," y2 - 120 ")", downs - d0 = 2 && clicks - c0 = 2 && x2 > 150)
ExitApp()
