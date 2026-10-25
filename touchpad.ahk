; The touchpad tile in the grid. Included by touchdock.ahk, which owns the globals.
; One finger moves the pointer by its own movement (not to where the finger is); a tap clicks; a two-finger tap
; right-clicks; touch and hold right-clicks; tap, then touch again and slide drags.
; The pad handles the touch messages itself: passed on, Windows turns them into mouse moves that jump the
; pointer to the finger (measured with tests\touch-probe.ahk over Remote Desktop).

; Plain area, no click handling of its own (no SS_NOTIFY): its touches reach the grid window, where OnPointer takes them.
AddPad(x, y, w, h) {
    Bar.SetFont("s" Round(G.pt * 0.15) " c5A5A5A", "Segoe UI")
    Bar.AddText("x" x " y" y " w" w " h" h " Center +0x200 Background" PadColor, "Touchpad")
    Pads.Push([x, y, w, h])
    PadArrows()  ; made now, not in the middle of a touch
}

PadState() {
    static st := {ids: Map(), last: 0, first: 0, moved: 0, two: false, held: false, dragging: false, lastTap: 0, fx: 0.0, fy: 0.0}
    return st
}

OnPad(x, y) {
    for p in Pads
        if (x >= p[1] && x < p[1] + p[3] && y >= p[2] && y < p[2] + p[4])
            return true
    return false
}

; WM_POINTERDOWN / UPDATE / UP. Returns 0 for the pad's own touches (handled), nothing for everything else.
OnPointer(wParam, lParam, msg, hwnd) {
    if (Bar && !EditMode && TileOf.Has(hwnd))
        return TileTouch(TileOf[hwnd], msg)
    if (!Bar || EditMode || !Pads.Length || hwnd != Bar.Hwnd)
        return
    st := PadState()
    id := wParam & 0xFFFF
    x := lParam & 0xFFFF, y := (lParam >> 16) & 0xFFFF
    x := (x >= 0x8000) ? x - 0x10000 : x, y := (y >= 0x8000) ? y - 0x10000 : y  ; screen positions can be negative
    if (msg = 0x246) {  ; a finger touches
        if (st.ids.Count && A_TickCount - st.last > 400)
            st.ids.Clear()  ; a lift that never arrived: start over
        st.last := A_TickCount
        if !st.ids.Count {
            WinGetPos(&bx, &by, , , Bar)
            if !OnPad(x - bx, y - by)
                return  ; the grid's background, not a pad
            st.first := id, st.moved := 0, st.two := false, st.held := false, st.fx := 0.0, st.fy := 0.0
            ; Tap, then touch again soon: hold the button down and drag until the finger lifts.
            if (A_TickCount - st.lastTap < 350)
                Click("Down"), st.dragging := true
            SetTimer(PadHold, -600)
        } else
            st.two := true
        st.ids[id] := [x, y]
        PadArrowShow()
        return 0
    }
    if !st.ids.Has(id)
        return
    st.last := A_TickCount
    if (msg = 0x245) {  ; a finger moves
        if (id = st.first && !st.two) {
            last := st.ids[id]
            dx := x - last[1], dy := y - last[2]
            st.moved += Abs(dx) + Abs(dy)
            ; Small wobble while tapping does not move the pointer.
            if (st.moved > 6 || st.dragging) {
                f := PadSpeeds[PadSpeed]
                st.fx += dx * f, st.fy += dy * f
                mx := Integer(st.fx), my := Integer(st.fy)
                st.fx -= mx, st.fy -= my
                if (mx || my)
                    DllCall("mouse_event", "UInt", 1, "Int", mx, "Int", my, "UInt", 0, "UPtr", 0), PadArrowShow()  ; relative move
            }
        }
        st.ids[id] := [x, y]
        return 0
    }
    ; a finger lifts; the first finger lifting ends the gesture (the others' lifts may not all arrive)
    st.ids.Delete(id)
    if (id = st.first)
        st.ids.Clear()
    if st.ids.Count
        return 0
    SetTimer(PadHold, 0)
    if st.dragging {
        Click("Up"), st.dragging := false
        ReleaseLatched()
    } else if (!st.held && st.two && st.moved <= 20) {
        Click("Right"), st.lastTap := 0
        ReleaseLatched()
    } else if (!st.held && !st.two && st.moved <= 6) {
        Click(), st.lastTap := A_TickCount
        ReleaseLatched()  ; the script's own clicks do not trigger the click that lets Ctrl/Shift/Alt go
    }
    return 0
}

; One finger held still for 0.6 s: right click.
PadHold() {
    st := PadState()
    if (st.ids.Count = 1 && !st.two && !st.dragging && st.moved <= 6) {
        st.held := true
        Click("Right")
        ReleaseLatched()
    }
}

; A finger on a key tile. Windows turns a finger held still into a mouse press only when it lifts, so holding a
; key would not repeat; the touch itself presses the key at once, and lifting the finger ends the repeat.
; Tabs are left to the mouse path: a press and slide on a tab drags the grid.
TileTouch(t, msg) {
    global TouchHeld
    if (t[1].kind = "tab")
        return
    if (msg = 0x246) {
        TouchHeld := true
        SetTimer(PressTile.Bind(t[1], t[2], t[3]), -1)  ; its own thread, so the lift below can arrive meanwhile
    } else if (msg = 0x247)
        TouchHeld := false
    return 0
}

PickPadSpeed(name, *) {
    global PadSpeed := name
    IniWrite(name, IniFile, "look", "padspeed")
}

; ---------- the drawn pointer ----------
; In Touch mode the tablet's Remote Desktop app does not draw the pointer, so the pad draws an arrow of its own
; on the PC, which reaches the tablet as part of the screen. It shows while the pad is used and 3 s after.
; Click-through, so clicks land on what is under it.

PadArrows() {
    static arrows := ""
    if arrows
        return arrows
    s := A_ScreenDPI / 96 * 1.4
    shapes := [["000000", [[0, 0], [0, 21], [5, 16], [9, 25], [13, 23], [9, 15], [16, 15]]],
        ["FFFFFF", [[1.5, 3.5], [1.5, 17.5], [5.5, 13.5], [9.6, 22], [11, 21.3], [7, 13.3], [12.3, 13.3]]]]
    arrows := []
    for sh in shapes {  ; a black outline under a white arrow
        g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000020", "TouchDock Pointer")  ; no-activate, click-through
        g.BackColor := sh[1]
        g.Show("x0 y0 w" Round(17 * s) " h" Round(26 * s) " NoActivate Hide")
        WinSetTransparent(254, g)  ; layered, which click-through needs (255 would switch layering off)
        pts := ""
        for p in sh[2]
            pts .= Round(p[1] * s) "-" Round(p[2] * s) " "
        WinSetRegion(pts, g)
        arrows.Push(g)
    }
    return arrows
}

PadArrowShow() {
    PadArrowFollow()
    if !DllCall("IsWindowVisible", "Ptr", PadArrows()[1].Hwnd)
        for g in PadArrows()
            g.Show("NoActivate")
    SetTimer(PadArrowFollow, 10)
    SetTimer(PadArrowHide, -3000)  ; restarted by every touch on the pad
}

PadArrowFollow() {
    static lx := "", ly := ""
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    if (x = lx && y = ly)
        return
    lx := x, ly := y
    for g in PadArrows()
        g.Move(x, y)  ; the arrow's tip on the pointer's spot
}

PadArrowHide() {
    SetTimer(PadArrowFollow, 0)
    for g in PadArrows()
        g.Hide()
}
