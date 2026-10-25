#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; touch-probe.ahk : records what a finger on the grey pad sends over Remote Desktop, one guided step at a time,
; into tests\touch-log.txt. Buttons: Next step, Redo step, Finish.
CoordMode("Mouse", "Screen")
steps := ["Slide one finger slowly across the pad", "Tap the pad once", "Tap the pad with two fingers at the same time",
    "Touch the pad and hold still for 1 second", "Tap, then touch again quickly and slide"]
lines := Map(), counts := Map()
for i, s in steps
    lines[i] := [], counts[i] := {downs: 0, ids: Map()}
cur := 1, t0 := A_TickCount

W := Gui("+AlwaysOnTop +ToolWindow -DPIScale +E0x08000000", "Touch probe")
W.BackColor := "202020"
W.SetFont("s15 cWhite", "Segoe UI")
title := W.AddText("x20 y12 w760 h34")
W.SetFont("s11 cAAAAAA")
progress := W.AddText("x20 y48 w760 h24")
W.SetFont("s14 c909090")
pad := W.AddText("x20 y80 w760 h330 Center +0x200 Background3A3A3A", "pad")
W.SetFont("s13 cWhite")
bNext := W.AddText("x20 y425 w240 h56 Center +0x200 Background1C5FC4", "Next step")
bRedo := W.AddText("x280 y425 w240 h56 Center +0x200 Background444444", "Redo step")
bDone := W.AddText("x540 y425 w240 h56 Center +0x200 Background7A2A2A", "Finish")
bNext.OnEvent("Click", (*) => Go(1))
bRedo.OnEvent("Click", (*) => Go(0))
bDone.OnEvent("Click", (*) => Finish())
W.Show("w800 h500 NoActivate")
for h in [W.Hwnd, pad.Hwnd]
    DllCall("SetProp", "Ptr", h, "Str", "MicrosoftTabletPenServiceProperty", "Ptr", 1)  ; no hold = right click
names := Map(0x200, "mousemove", 0x201, "LDOWN", 0x202, "LUP", 0x203, "LDBL", 0x204, "RDOWN", 0x205, "RUP",
    0x246, "PTRDOWN", 0x245, "PTRUPDATE", 0x247, "PTRUP")
for msg in names
    OnMessage(msg, Rec)
Show()

Show() {
    title.Value := "Step " cur " of " steps.Length ":  " steps[cur]
    p := ""
    for i, s in steps
        p .= (i < cur ? Chr(0x2713) : i = cur ? Chr(0x25B6) : Chr(0x25CB)) " " i "   "
    c := counts[cur]
    progress.Value := p "      this step: " c.downs " touches, " c.ids.Count " finger(s) seen"
    bNext.Value := (cur = steps.Length) ? "Last step" : "Next step"
}

Go(d) {
    global cur
    if (d = 0) {  ; redo: forget this step's records
        lines[cur] := [], counts[cur] := {downs: 0, ids: Map()}
    } else if (cur < steps.Length)
        cur += 1
    Show()
}

Rec(wParam, lParam, msg, hwnd) {
    if (hwnd != pad.Hwnd && hwnd != W.Hwnd)
        return  ; the buttons are not part of the test
    MouseGetPos(&px, &py)
    extra := DllCall("GetMessageExtraInfo", "Ptr")
    src := ((extra & 0xFFFFFF00) = 0xFF515700) ? ((extra & 0x80) ? "touch" : "pen") : "mouse"
    line := Format("{:6} {:-10} pointer {},{}  from {}", A_TickCount - t0, names[msg], px, py, src)
    if (msg >= 0x245 && msg <= 0x247) {
        id := wParam & 0xFFFF, type := 0
        DllCall("GetPointerType", "UInt", id, "UInt*", &type)
        x := lParam & 0xFFFF, y := (lParam >> 16) & 0xFFFF
        line .= Format("  [finger id {} type {} at {},{}]", id, type, x, y)
        counts[cur].ids[id] := true
        if (msg = 0x246)
            counts[cur].downs += 1
        Show()
    }
    lines[cur].Push(line)
}

Finish() {
    f := FileOpen(A_ScriptDir "\touch-log.txt", "w", "UTF-8")
    for i, s in steps {
        f.WriteLine("== Step " i ": " s "  (" counts[i].downs " touches, " counts[i].ids.Count " finger ids)")
        for l in lines[i]
            f.WriteLine(l)
    }
    f.Close()
    ExitApp()
}
