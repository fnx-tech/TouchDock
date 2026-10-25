; Edit buttons around the mic button. Included at the end of touchdock.ahk, which owns the globals.

; ---------- edit buttons (beside the mic button) ----------
; WS_EX_NOACTIVATE as on the button: the keys must land in the app you were typing in, not here.

BuildBar() {
    global Bar, BarW, BarH, BarIcons, MicAt, MicW, MicH, G
    Critical  ; no timer (the layouts-file watch, the touchpad pointer) may run while the grid is half-built
    ReleaseLatched(true)  ; sticky ones too: their tile is about to go (another layout, or the editor)
    if Bar
        Bar.Destroy(), Bar := ""
    for h in BarIcons
        DllCall("DestroyIcon", "Ptr", h)
    BarIcons := [], MicAt := "", TileOf.Clear(), Pads.Length := 0
    if (!EditMode && (!ShowBar || Hidden)) {
        ShowEditBox(false)
        return ShapeBtn()
    }
    layouts := EditMode ? EditLayouts : LoadButtons()
    if !layouts.Length
        return ShapeBtn()
    cfg := CurLayout(layouts)
    ; Two tiles and the gap between them are exactly the mic button, so a 2 x 2 mic is the size it has on its own.
    px := Round(Sizes[SizeName] * A_ScreenDPI / 96)
    gap := Max(2, Round(px * 0.05))
    s := (px - gap) // 2
    base := s * 96 / A_ScreenDPI
    ; The tab row picks the layout, and is a handle for dragging the grid.
    tabH := (layouts.Length > 1 || EditMode) ? Round(s * 0.5) : 0
    top := tabH ? gap + tabH + gap : gap
    G := {s: s, gap: gap, top: top, pt: base}  ; not "base": that name is every object's parent
    BarW := cfg.cols * s + (cfg.cols + 1) * gap, BarH := top + cfg.rows * (s + gap)

    Bar := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000", "TouchDock Grid")
    Bar.BackColor := "1A1A1A"
    Bar.MarginX := 0, Bar.MarginY := 0
    if tabH {
        Bar.SetFont("s" Round(base * 0.15) " cWhite", "Segoe UI")
        n := layouts.Length, tw := (BarW - (n + 1) * gap) // n
        for i, l in layouts {
            color := (l = cfg) ? TilePressed : TileColor
            x := gap + (i - 1) * (tw + gap)
            w := (i = n) ? BarW - gap - x : tw
            t := Bar.AddText("x" x " y" gap " w" w " h" tabH " Center +0x200 +0x100 Background" color, l.name)
            TileOf[t.Hwnd] := [{kind: "tab", what: l.name, label: l.name}, [t], color]
        }
    }
    if EditMode
        AddEmptySpots(cfg)
    for k in cfg.items {
        x := gap + k.col * (s + gap), y := top + k.row * (s + gap)
        w := k.w * s + (k.w - 1) * gap, h := k.h * s + (k.h - 1) * gap
        if (k.kind = "mic") {
            MicAt := [x, y], MicW := w, MicH := h
            ; In the editor the mic is a tile, so it moves and resizes like the rest.
            if EditMode
                AddTile({label: "Mic", kind: "keys", what: "", icon: "E720"}, k, x, y, w, h, TilePressed)
        } else if (k.kind = "touchpad") {
            if EditMode
                AddTile({label: "Touchpad", kind: "keys", what: "", icon: ""}, k, x, y, w, h, PadColor)
            else
                AddPad(x, y, w, h)
        } else
            AddTile(k, k, x, y, w, h, (k.label = "Enter") ? EnterColor : TileColor)
    }
    if EditMode
        Btn.Hide()
    else
        ShapeBtn()
    PlaceBar()
    ; Rounded grid with a hole where the mic sits: tapping a tile lifts the grid above the mic,
    ; and the hole keeps it from covering the mic when that happens.
    rr := gap * 3
    rgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", BarW + 1, "Int", BarH + 1, "Int", rr, "Int", rr, "Ptr")
    if (MicAt && !EditMode) {
        hole := DllCall("CreateRoundRectRgn", "Int", MicAt[1], "Int", MicAt[2], "Int", MicAt[1] + MicW + 1, "Int", MicAt[2] + MicH + 1, "Int", Min(MicW, MicH), "Int", Min(MicW, MicH), "Ptr")
        DllCall("CombineRgn", "Ptr", rgn, "Ptr", rgn, "Ptr", hole, "Int", 4)  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", hole)
    }
    DllCall("SetWindowRgn", "Ptr", Bar.Hwnd, "Ptr", rgn, "Int", true)  ; Windows owns rgn from here
    ApplyAlpha()
    ShowEditBox(EditMode)
}

; One button: what it shows comes from disp, what a press does from k.
AddTile(disp, k, x, y, w, h, color) {
    s := G.s, base := G.pt
    big := (Min(k.w, k.h) >= 2) ? 1.6 : 1
    ; Under an icon, a two-word name takes two lines ("Close" over "tab").
    twoLines := InStr(disp.label, " ") && (disp.icon != "" || disp.kind = "open")
    labH := (disp.label = "") ? 0 : Round(s * (twoLines ? 0.56 : 0.38))
    ctrls := []
    hIcon := (disp.kind = "open") ? FileIcon(disp.what) : 0
    if hIcon {
        BarIcons.Push(hIcon)
        ; SS_ICON | SS_CENTERIMAGE: the program's own icon, centred on the tile colour.
        ic := Bar.AddText("x" x " y" y " w" w " h" h - labH " +0x203 Background" color)
        SendMessage(0x170, hIcon, 0, ic)  ; STM_SETICON
        ctrls.Push(ic)
    } else if (disp.icon != "") {
        Bar.SetFont("s" Round(base * (labH ? 0.28 : 0.36) * big) " cWhite", "Segoe Fluent Icons")
        ctrls.Push(Bar.AddText("x" x " y" y " w" w " h" h - labH " Center +0x200 Background" color, Chr("0x" disp.icon)))
    }
    if (ctrls.Length && labH) {
        Bar.SetFont("s" Round(base * 0.12) " cDDDDDD", "Segoe UI")
        ctrls.Push(Bar.AddText("x" x " y" y + h - labH " w" w " h" labH " Center Background" color, StrReplace(disp.label, " ", "`n", , , 1)))
    } else if !ctrls.Length {
        pt := Round(base * 0.17 * big)
        Bar.SetFont("s" pt " cWhite", "Segoe UI")
        if InStr(disp.label, " ") {
            ; Two words, two lines ("Reopen" over "tab"). A text control centres only one line by itself,
            ; so a strip of tile colour above pushes the two lines to the middle.
            pad := Max(0, (h - 2 * Round(pt * A_ScreenDPI / 72 * 1.35)) // 2)
            if pad
                ctrls.Push(Bar.AddText("x" x " y" y " w" w " h" pad " Background" color))
            ctrls.Push(Bar.AddText("x" x " y" y + pad " w" w " h" h - pad " Center Background" color, StrReplace(disp.label, " ", "`n", , , 1)))
        } else
            ctrls.Push(Bar.AddText("x" x " y" y " w" w " h" h " Center +0x200 Background" color, disp.label))
    }
    ; Pressed on mouse down (OnLeftDown), so holding a tile can repeat its key.
    for ctl in ctrls {
        ctl.Opt("+0x100")  ; SS_NOTIFY: without it a text control lets clicks fall through to the window
        TileOf[ctl.Hwnd] := [k, ctrls, color]
        ; Touch over Remote Desktop: no press-and-hold right-click on tiles, or holding an arrow never repeats.
        DllCall("SetProp", "Ptr", ctl.Hwnd, "Str", "MicrosoftTabletPenServiceProperty", "Ptr", 1)  ; TABLET_DISABLE_PRESSANDHOLD
    }
}

; Round when square, a pill when longer one way; the plain round button when the grid is off.
ShapeBtn() {
    global MicW, MicH
    if !MicAt
        MicW := MicH := Round(Sizes[SizeName] * A_ScreenDPI / 96)
    Btn.Move(, , MicW, MicH)
    ; In the grid the window stays square and the picture draws the circle with smooth edges on the grid's colour.
    ; On its own, a round cut-out shows the desktop around it (its edge is not smoothed).
    if MicAt
        WinSetRegion(, Btn)
    else
        WinSetRegion("0-0 w" MicW " h" MicH " E", Btn)
    RenderMic()
}

; Draws the mic (circle or pill, in the state's colour, with the mic symbol) with GDI+ anti-aliasing.
RenderMic() {
    static token := 0
    if (!MicW || !MicH)
        return
    if !token {
        DllCall("LoadLibrary", "Str", "gdiplus")
        si := Buffer(24, 0), NumPut("UInt", 1, si)
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
    }
    w := MicW, h := MicH, d := Min(w, h)
    fill := 0xFF000000 | Integer("0x" ((Engine = "windows") ? Colors["windows"] : Colors[State]))
    back := MicAt ? 0xFF1A1A1A : fill  ; in the grid, the corners show the grid's own colour
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bmp, "Ptr*", &g := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", g, "Int", 4)        ; anti-alias
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", g, "Int", 4)    ; anti-alias
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", g, "UInt", back)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", fill, "Ptr*", &br := 0)
    ; A circle, or for a pill: a circle at each end and the band between them.
    DllCall("gdiplus\GdipFillEllipse", "Ptr", g, "Ptr", br, "Float", 0.5, "Float", 0.5, "Float", d - 1, "Float", d - 1)
    if (w != h) {
        DllCall("gdiplus\GdipFillEllipse", "Ptr", g, "Ptr", br, "Float", w - d + 0.5, "Float", h - d + 0.5, "Float", d - 1, "Float", d - 1)
        if (h > w)
            DllCall("gdiplus\GdipFillRectangle", "Ptr", g, "Ptr", br, "Float", 0.5, "Float", d / 2, "Float", d - 1, "Float", h - d)
        else
            DllCall("gdiplus\GdipFillRectangle", "Ptr", g, "Ptr", br, "Float", d / 2, "Float", 0.5, "Float", w - d, "Float", d - 1)
    }
    ; The mic symbol from Segoe Fluent Icons, centred, white.
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe Fluent Icons", "Ptr", 0, "Ptr*", &fam := 0)
    DllCall("gdiplus\GdipCreateFont", "Ptr", fam, "Float", d * ((w = h) ? 0.36 : 0.42) * 1.33, "Int", 0, "Int", 2, "Ptr*", &font := 0)
    DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &fmt := 0)
    DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", fmt, "Int", 1)
    DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", fmt, "Int", 1)
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFFFFFFFF, "Ptr*", &white := 0)
    rect := Buffer(16)
    NumPut("Float", 0, "Float", 0, "Float", w, "Float", h, rect)
    DllCall("gdiplus\GdipDrawString", "Ptr", g, "WStr", Chr(0xE720), "Int", -1, "Ptr", font, "Ptr", rect, "Ptr", fmt, "Ptr", white)
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bmp, "Ptr*", &hbm := 0, "UInt", back)
    for f, h2 in Map("GdipDeleteBrush", br, "GdipDeleteFont", font, "GdipDeleteFontFamily", fam, "GdipDeleteStringFormat", fmt, "GdipDeleteGraphics", g, "GdipDisposeImage", bmp)
        DllCall("gdiplus\" f, "Ptr", h2)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", white)
    MicPic.Move(0, 0, w, h)
    MicPic.Value := "HBITMAP:" hbm  ; the control takes the bitmap and frees the previous one
}

PressTile(k, ctrls, color, *) {
    if (KeySounds && FileExist(ClickSound))
        try SoundPlay(ClickSound)
    if (k.kind = "tab") {
        ; Rebuilt from a timer: this runs inside a click on the grid that BuildBar destroys.
        global LayoutName := k.what
        IniWrite(LayoutName, IniFile, "look", "layout")
        SetTimer(BuildBar, -1)
        return
    }
    if (k.kind = "hold") {
        if Latched.Has(k.what) {
            Send("{" k.what " up}")
            Latched.Delete(k.what)
            Paint(ctrls, color)
        } else {
            ; Sent down and left down: Windows then applies it to the next key from any keyboard, or the next click.
            Send("{" k.what " down}")
            ; Sticky: stays down through any number of keys and clicks, until its tile is tapped again.
            Latched[k.what] := [ctrls, color, k.HasOwnProp("sticky") && k.sticky]
            Paint(ctrls, TilePressed)
            WatchNextKey()
        }
        return
    }
    Paint(ctrls, TilePressed)
    SetTimer(() => Paint(ctrls, color), -150)
    if (k.kind = "open") {
        try Run(ExpandEnv(k.what))
        catch
            TrayTip("Could not open " k.what, "TouchDock")
    } else if (k.kind = "text") {
        SendText(k.what)
    } else {
        for step in StrSplit(k.what, " ", "`t")
            if (step != "")
                Send(step), Sleep(30)
        ; Held down, the keys repeat like a keyboard key. "repeat on/off" decides; without it, a single key with no
        ; Ctrl/Shift/Alt/Win (arrows, Backspace, Delete) repeats. A held Ctrl/Shift stays on meanwhile.
        if (k.repeat = "on" || (k.repeat = "" && k.what ~= "^\{\w+\}$")) {
            start := A_TickCount, lastClick := 0
            Paint(ctrls, TilePressed)
            while (TouchHeld || GetKeyState("LButton")) && A_TickCount - start < 20000 {
                if (A_TickCount - start > 400) {
                    for step in StrSplit(k.what, " ", "`t")
                        if (step != "")
                            Send(step)
                    ; A click on every other repeat (about 10 a second) says the key is still being pressed.
                    if (KeySounds && FileExist(ClickSound) && A_TickCount - lastClick >= 100)
                        try SoundPlay(ClickSound), lastClick := A_TickCount
                    Sleep(50)
                } else
                    Sleep(10)
            }
            Paint(ctrls, color)
        }
    }
    ReleaseLatched()
}

Paint(ctrls, color) {
    try for c in ctrls
        c.Opt("Background" color), c.Redraw()
}

; A held Ctrl / Shift / Alt is let go after the next key is released.
WatchNextKey() {
    global NextKey
    if NextKey
        return
    NextKey := InputHook("V")
    NextKey.KeyOpt("{All}", "N")
    NextKey.KeyOpt("{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}", "-N")
    NextKey.OnKeyUp := (*) => ReleaseLatched()
    NextKey.Start()
}

; Lets go of the held Ctrl / Shift / Alt; sticky ones only when all is true.
ReleaseLatched(all := false) {
    global NextKey
    for mod in [Latched*]  ; a copy of the names, since entries are removed on the way
        if (all || !Latched[mod][3]) {
            Send("{" mod " up}")
            Paint(Latched[mod][1], Latched[mod][2])
            Latched.Delete(mod)
        }
    if (NextKey && !Latched.Count)
        NextKey.Stop(), NextKey := ""
}

; ...or after the next click outside the edit buttons (Shift+click, Ctrl+click).
; These two install the mouse hook, which reports Remote Desktop clicks as not physical:
; read the mouse buttons with GetKeyState(key), never with "P", or dragging and the menu stop working.
~*LButton Up::ClickReleases()
~*RButton Up::ClickReleases()
ClickReleases() {
    if !Latched.Count
        return
    MouseGetPos(, , &win)
    if (Bar && win = Bar.Hwnd)
        return
    ReleaseLatched()
}

; Large shell icon of a program, folder or file; 0 for anything else (a web address, a path with arguments).
FileIcon(path) {
    path := ExpandEnv(path)
    if !FileExist(path)
        return 0
    info := Buffer(A_PtrSize + 688, 0)  ; SHFILEINFOW
    if !DllCall("shell32\SHGetFileInfoW", "WStr", path, "UInt", 0, "Ptr", info, "UInt", info.Size, "UInt", 0x100)  ; SHGFI_ICON
        return 0
    return NumGet(info, 0, "Ptr")
}

ExpandEnv(s) {
    buf := Buffer(8192)
    DllCall("ExpandEnvironmentStringsW", "Str", s, "Ptr", buf, "UInt", 4096)
    return StrGet(buf)
}

WatchButtonsFile() {
    if EditMode
        return
    try t := FileGetTime(ButtonsFile, "M")
    catch
        t := ""
    if (t != ButtonsTime)
        BuildBar()
}

OpenButtonsFile() => Run('notepad.exe "' ButtonsFile '"')

; With the mic in the grid, the grid sits around it; otherwise beside it, on whichever side has room.
PlaceBar() {
    if !Bar
        return
    if EditMode {  ; the grid stays where it was when editing started, or where its tabs dragged it
        Bar.Show("x" EditPos[1] " y" EditPos[2] " w" BarW " h" BarH " NoActivate")
        return
    }
    WinGetPos(&bx, &by, &bw, &bh, Btn)
    if MicAt {
        Bar.Show("x" bx - MicAt[1] " y" by - MicAt[2] " w" BarW " h" BarH " NoActivate")
        WinMoveTop(Btn)  ; both are always-on-top; the mic must stay above the grid's background
        return
    }
    MonitorGetWorkArea(MonitorAt(bx + bw // 2, by + bh // 2), &l, &t, &r, &b)
    gap := Round(8 * A_ScreenDPI / 96)
    x := (bx - BarW - gap >= l) ? bx - BarW - gap : bx + bw + gap
    y := Min(Max(by + bh // 2 - BarH // 2, t), b - BarH)
    Bar.Show("x" x " y" y " w" BarW " h" BarH " NoActivate")
}

ToggleBar() {
    global ShowBar := !ShowBar
    IniWrite(ShowBar ? 1 : 0, IniFile, "look", "editbar")
    BuildBar()
}

MonitorAt(px, py) {
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (px >= l && px < r && py >= t && py < b)
            return A_Index
    }
    return MonitorGetPrimary()
}
