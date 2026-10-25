#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; sticky-test.ahk : on the Keys layout, taps the sticky Ctrl tile, then the Down-arrow tile twice, and checks Ctrl
; is still held; then taps Ctrl again and checks it is let go. Simulated finger taps; the session must be connected.
SetTimer(() => (FileAppend("timeout`n", "*"), ExitApp()), -30000)
Check(name, ok) => FileAppend((ok ? "ok    " : "FAIL  ") name "`n", "*")
g := WinExist("TouchDock Grid")
Find(text) {
    for h in WinGetControlsHwnd(g)
        if (ControlGetText(h) = text)
            return h
}
TapTile(h) {
    WinGetPos(&gx, &gy, , , g)
    ControlGetPos(&cx, &cy, &cw, &ch, h)
    buf := Buffer(144, 0)
    NumPut("UInt", 2, buf, 0), NumPut("Int", gx + cx + cw // 2, buf, 32), NumPut("Int", gy + cy + ch // 2, buf, 36)
    NumPut("UInt", 0x10006, buf, 12), DllCall("InjectTouchInput", "UInt", 1, "Ptr", buf), Sleep(30)
    NumPut("UInt", 0x40000, buf, 12), DllCall("InjectTouchInput", "UInt", 1, "Ptr", buf), Sleep(400)
}
DllCall("InitializeTouchInjection", "UInt", 1, "UInt", 3)
ctrl := Find("Ctrl"), down := Find(Chr(0xE74B))
if (!ctrl || !down) {
    FileAppend("the Keys layout is not showing`n", "*")
    ExitApp(1)
}
TapTile(ctrl)
Check("Ctrl held after tapping it", GetKeyState("Ctrl"))
TapTile(down), TapTile(down)
Check("sticky Ctrl still held after two other keys", GetKeyState("Ctrl"))
TapTile(ctrl)
Check("tapping Ctrl again lets it go", !GetKeyState("Ctrl"))
ExitApp()
