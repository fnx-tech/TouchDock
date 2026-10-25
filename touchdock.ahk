#Requires AutoHotkey v2.0
#SingleInstance Force
; Floating mic button for Handy or Windows voice typing: click or Win+H = start/stop dictation, drag = move, right-click = menu.

HandyExe     := EnvGet("LOCALAPPDATA") "\Handy\handy.exe"
HandySettings := EnvGet("APPDATA") "\com.pais.handy\settings_store.json"
IniFile      := A_ScriptDir "\touchdock.ini"
StartupLink  := A_Startup "\TouchDock.lnk"

; Values are Handy's "selected_model" ids: <catalog repo>/<file name>.
Models := Map(
    "English, fast (Parakeet V2)", "handy-computer/parakeet-tdt-0.6b-v2-gguf/parakeet-tdt-0.6b-v2-Q8_0.gguf",
    "English, live text (Parakeet Unified EN)", "handy-computer/parakeet-unified-en-0.6b-gguf/parakeet-unified-en-0.6b-Q8_0.gguf",
    "Arabic + English (Cohere Transcribe)", "handy-computer/cohere-transcribe-03-2026-gguf/cohere-transcribe-03-2026-Q5_K_M.gguf"
)
; Mic button width in pixels at 100 % display scale; 100 % is the old "Medium".
SizeNames := ["50%", "75%", "100%", "125%", "150%"]  ; menu order (a Map lists "100%" before "50%")
Sizes := Map("50%", 56, "75%", 84, "100%", 112, "125%", 140, "150%", 168)

HandyLog     := EnvGet("LOCALAPPDATA") "\com.pais.handy\logs\handy.log"
Colors := Map("idle", "2B2B2B", "recording", "C42B1C", "transcribing", "C47F1C", "windows", "1C5FC4")
Engines := Map("handy", "Handy (local)", "windows", "Windows voice typing")
Opacities := [100, 90, 80, 70, 60, 50, 40, 30, 20, 10]
State := "idle"         ; Handy's real state, read from its log: idle / recording / transcribing
LastPress := 0
LogPos := 0

SizeName  := IniRead(IniFile, "look", "size", "100%")
if !Sizes.Has(SizeName)  ; a name from before the percentages, or a typo
    SizeName := "100%"
Opacity   := Integer(IniRead(IniFile, "look", "opacity", "100"))
KeySounds := IniRead(IniFile, "look", "sounds", "1") = "1"
LayoutName := IniRead(IniFile, "look", "layout", "")
Hidden    := IniRead(IniFile, "look", "hidden", "0") = "1"
HandyInstalled := FileExist(HandyExe) != ""
; Without Handy the Handy-only items are hidden and Windows voice typing is used, whatever was saved.
Engine    := HandyInstalled ? IniRead(IniFile, "engine", "name", "handy") : "windows"
ShowBar   := IniRead(IniFile, "look", "editbar", "1") = "1"

; Edit buttons around the mic button, one per line of layouts.txt (format in that file).
ButtonsFile := A_ScriptDir "\layouts.txt"
ClickSound := A_ScriptDir "\click.wav"
TileColor := "333333", TilePressed := "1C5FC4", EnterColor := "1F4E8C"
Bar := "", BarW := 0, BarH := 0, BarIcons := [], MicAt := "", MicW := 0, MicH := 0, ButtonsTime := "", NextKey := ""
EditMode := false, EditLayouts := "", EditUndo := [], EditPos := "", EditStartLayout := "", EditBox := "", Picker := ""
EmptyColor := "262626", PadColor := "2A2A2A"
Pads := []         ; touchpads of the shown layout: [x, y, w, h] inside the grid window
PadSpeeds := Map("Slow", 1.2, "Normal", 2, "Fast", 3)
PadSpeed := IniRead(IniFile, "look", "padspeed", "Normal")
if !PadSpeeds.Has(PadSpeed)
    PadSpeed := "Normal"
LastRefusal := ""   ; what the editor last refused, as shown in its tooltip
BackupFile := A_ScriptDir "\layouts.bak"
G := ""            ; grid geometry of the last build: {s, gap, top, pt}
TouchHeld := false  ; a finger is still on the tile it pressed (touchpad.ahk)
TileOf := Map()    ; tile control hwnd -> [button, its controls, its colour]
Latched := Map()   ; held "Ctrl" / "Shift" / "Alt" -> [its tile's controls, its colour]

; Physical pixels: the round cut-out ignores display scaling, so the window must too (-DPIScale).
; WS_EX_NOACTIVATE (0x08000000): clicking must not take focus, or Handy pastes into this button instead of the app you were typing in.
Btn := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000", "TouchDock")
Btn.BackColor := Colors["idle"]
Btn.MarginX := 0, Btn.MarginY := 0
Icon := Btn.AddText("x0 y0 Center +0x200 BackgroundTrans Hidden", Chr(0xE720))
; The mic is a picture drawn smooth by RenderMic; it lets clicks through to the window.
MicPic := Btn.AddPicture("x0 y0 w10 h10")

HideLabel := "Hide button"
HandyLabel := "Restart Handy"
FillMenu(A_TrayMenu)
A_IconTip := "TouchDock"

ApplySize(true)
SetState("idle")

try LogPos := FileOpen(HandyLog, "r").Length
SetTimer(WatchLog, 250)
SetTimer(WatchButtonsFile, 1000)
OnExit((*) => ReleaseLatched(true))

OnMessage(0x201, OnLeftDown)        ; WM_LBUTTONDOWN
OnMessage(0x246, OnPointer)        ; WM_POINTERDOWN: touches on a touchpad tile (touchpad.ahk)
OnMessage(0x245, OnPointer)        ; WM_POINTERUPDATE
OnMessage(0x247, OnPointer)        ; WM_POINTERUP
OnMessage(0x203, OnLeftDown)        ; WM_LBUTTONDBLCLK: a quick second tap on a tile arrives as this, not as a down
OnMessage(0x204, OnRightDown)       ; WM_RBUTTONDOWN
OnMessage(0x232, (*) => SavePos())  ; WM_EXITSIZEMOVE: a drag has ended
; Over Remote Desktop the tablet's keyboard opening or closing resizes the screen.
OnMessage(0x7E, (*) => SetTimer(KeepOnScreen, -700))  ; WM_DISPLAYCHANGE
OnMessage(0x1A, (*) => SetTimer(KeepOnScreen, -700))  ; WM_SETTINGCHANGE: the work area changed
OnMessage(0x3, (w, l, m, hwnd) => (hwnd = Btn.Hwnd) ? PlaceBar() : "")  ; WM_MOVE: the edit buttons follow the mic button

; Win+H follows the chosen engine; Exit gives Win+H back to Windows.
; $: the Win+H this script sends for Windows voice typing must not land back here.
$#h::Toggle()

; ---------- menu ----------

FillMenu(m) {
    global SizeMenu, ModelMenu
    m.Delete()
    m.Add("Start / stop dictation", (*) => Toggle())
    global EngineMenu := Menu()
    for key, label in Engines
        if (HandyInstalled || key != "handy")
            EngineMenu.Add(label, PickEngine)
    m.Add("Dictation engine", EngineMenu)
    m.Add()
    if HandyInstalled {
        ModelMenu := Menu()
        for name in Models
            ModelMenu.Add(name, SwitchModel)
        m.Add("Model", ModelMenu)
        m.Add()
    }
    SizeMenu := Menu()
    for name in SizeNames
        SizeMenu.Add(name, PickSize)
    m.Add("Size", SizeMenu)
    global OpacityMenu := Menu()
    for pct in Opacities
        OpacityMenu.Add(pct "%", PickOpacity.Bind(pct))
    m.Add("Opacity", OpacityMenu)
    global PadSpeedMenu := Menu()
    for name in ["Slow", "Normal", "Fast"]
        PadSpeedMenu.Add(name, PickPadSpeed.Bind(name))
    m.Add("Touchpad speed", PadSpeedMenu)
    m.Add("Key sounds", (*) => ToggleSounds())
    m.Add("Show keys grid", (*) => ToggleBar())
    m.Add("Edit layout (drag and drop)", (*) => StartEdit())
    m.Add("Edit layout (text file)", (*) => OpenButtonsFile())
    m.Add(HideLabel, (*) => ToggleHidden())
    m.Add("Move to corner " Chr(0x2198), (*) => ResetPos())
    m.Add()
    if HandyInstalled {
        m.Add("Open Handy", (*) => OpenHandy())
        m.Add(HandyLabel, (*) => RestartHandy())
    }
    m.Add("Start with Windows", (*) => ToggleStartup())
    m.Add()
    m.Add("Restart TouchDock", (*) => Reload())
    m.Add("Exit", (*) => ExitApp())
}

RefreshChecks() {
    global HideLabel, HandyLabel
    m := A_TrayMenu
    for name in SizeNames
        (name = SizeName) ? SizeMenu.Check(name) : SizeMenu.Uncheck(name)
    for key, label in Engines
        if (HandyInstalled || key != "handy")
            (key = Engine) ? EngineMenu.Check(label) : EngineMenu.Uncheck(label)
    if HandyInstalled {
        current := CurrentModel()
        for name, id in Models
            (id = current) ? ModelMenu.Check(name) : ModelMenu.Uncheck(name)
    }
    for pct in Opacities
        (pct = Opacity) ? OpacityMenu.Check(pct "%") : OpacityMenu.Uncheck(pct "%")
    for name in ["Slow", "Normal", "Fast"]
        (name = PadSpeed) ? PadSpeedMenu.Check(name) : PadSpeedMenu.Uncheck(name)
    KeySounds ? m.Check("Key sounds") : m.Uncheck("Key sounds")
    ShowBar ? m.Check("Show keys grid") : m.Uncheck("Show keys grid")
    want := Hidden ? "Show button" : "Hide button"
    if (want != HideLabel)
        m.Rename(HideLabel, want), HideLabel := want
    if HandyInstalled {
        want := HandyRunning() ? "Restart Handy" : "Start Handy"
        if (want != HandyLabel)
            m.Rename(HandyLabel, want), HandyLabel := want
    }
    FileExist(StartupLink) ? m.Check("Start with Windows") : m.Uncheck("Start with Windows")
}

ShowMenu() {
    RefreshChecks()
    A_TrayMenu.Show()
}

; Refresh ticks and labels before the tray menu opens.
OnMessage(0x404, OnTray)  ; AHK_NOTIFYICON
OnTray(wParam, lParam, *) {
    if (lParam = 0x205) {  ; WM_RBUTTONUP
        ShowMenu()
        return 1
    }
}

; ---------- big menu (button right-click) ----------
; A window of our own instead of a Windows menu, so its text can be larger than a standard menu (fixed at the 100 % size).
; WS_EX_NOACTIVATE for the same reason as the button: picking "Start / stop" must not move focus off your text.

Panel := ""
PanelArmed := false

Tick(on) => on ? Chr(0x2713) "  " : "     "

PanelItems(page) {
    items := []
    if (page = "main") {
        items.Push(["Start / stop dictation", Toggle])
        items.Push(["Dictation engine:  " Engines[Engine] "   " Chr(0x203A), () => ShowPanel("engine")])
        if HandyInstalled
            items.Push(["Model   " Chr(0x203A), () => ShowPanel("model")])
        items.Push(["Size:  " SizeName "   " Chr(0x203A), () => ShowPanel("size")])
        items.Push(["-"])
        items.Push(["Opacity:  " Opacity "%   " Chr(0x203A), () => ShowPanel("opacity")])
        items.Push(["Touchpad speed:  " PadSpeed "   " Chr(0x203A), () => ShowPanel("padspeed")])
        items.Push([Tick(KeySounds) "Key sounds", ToggleSounds])
        items.Push([Tick(ShowBar) "Show keys grid", ToggleBar])
        items.Push(["Edit layout (drag and drop)", StartEdit])
        items.Push(["Edit layout (text file)", OpenButtonsFile])
        items.Push([Hidden ? "Show button" : "Hide button", ToggleHidden])
        items.Push(["Move to corner " Chr(0x2198), ResetPos])
        items.Push(["-"])
        if HandyInstalled {
            items.Push(["Open Handy", OpenHandy])
            items.Push([HandyRunning() ? "Restart Handy" : "Start Handy", RestartHandy])
        }
        items.Push([Tick(FileExist(StartupLink)) "Start with Windows", ToggleStartup])
        items.Push(["-"])
        items.Push(["Restart TouchDock", () => Reload()])
        items.Push(["Exit", () => ExitApp()])
        return items
    }
    items.Push([Chr(0x2039) "  Back", () => ShowPanel("main")])
    items.Push(["-"])
    ; Braces needed: a loop directly followed by "else" takes that else as its own (runs when the loop is empty).
    if (page = "engine") {
        for key, label in Engines
            if (HandyInstalled || key != "handy")
                items.Push([Tick(key = Engine) label, PickEngine.Bind(label)])
    } else if (page = "model") {
        current := CurrentModel()
        for name, id in Models
            items.Push([Tick(id = current) name, SwitchModel.Bind(name)])
    } else if (page = "size") {
        for name in SizeNames
            items.Push([Tick(name = SizeName) name, PickSize.Bind(name)])
    } else if (page = "opacity") {
        for pct in Opacities
            items.Push([Tick(pct = Opacity) pct "%", PickOpacity.Bind(pct)])
    } else if (page = "padspeed") {
        for name in ["Slow", "Normal", "Fast"]
            items.Push([Tick(name = PadSpeed) name, PickPadSpeed.Bind(name)])
    }
    return items
}

; page: a page name for PanelItems, or a ready list of [text, action] items.
ShowPanel(page := "main") {
    global Panel, PanelArmed
    ClosePanel()
    pt := Round(Sizes["100%"] * 0.14)  ; the menu stays at the 100 % size whatever size the button is
    scale := A_ScreenDPI / 96
    rowH := Round(pt * 2.6 * scale)
    items := IsObject(page) ? page : PanelItems(page)
    ; As wide as the longest item, measured in the menu's own font, so no item is cut off.
    m := Gui("-DPIScale")
    m.SetFont("s" pt, "Segoe UI")
    w := Round(pt * 16 * scale)
    for item in items
        if (item[1] != "-") {
            m.AddText(, "   " item[1] "   ").GetPos(, , &tw)
            w := Max(w, tw)
        }
    m.Destroy()
    Panel := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +Border +E0x08000000")
    Panel.BackColor := "202020"
    Panel.MarginX := 0, Panel.MarginY := 0
    Panel.SetFont("s" pt " cF0F0F0", "Segoe UI")
    y := 0
    for item in items {
        if (item[1] = "-") {
            Panel.AddText("x0 y" y + Round(rowH * 0.15) " w" w " h1 Background505050")
            y += Round(rowH * 0.3)
            continue
        }
        t := Panel.AddText("x0 y" y " w" w " h" rowH " +0x200 Background202020", "   " item[1])
        t.OnEvent("Click", RunItem.Bind(item[2]))
        y += rowH
    }
    ; Beside the button (the grid while editing), on whichever side has room, kept inside the screen's work area.
    WinGetPos(&bx, &by, &bw, &bh, (EditMode && Bar) ? Bar : Btn)
    MonitorGetWorkArea(MonitorAt(bx + bw // 2, by + bh // 2), &l, &t, &r, &b)
    x := (bx - w - 8 >= l) ? bx - w - 8 : bx + bw + 8
    py := Min(Max(by + bh - y, t), b - y)
    Panel.Show("x" x " y" py " w" w " h" y " NoActivate")
    PanelArmed := false
    SetTimer(WatchOutside, 50)
}

RunItem(fn, *) {
    ClosePanel()
    fn()
}

ClosePanel() {
    global Panel
    SetTimer(WatchOutside, 0)
    if Panel {
        Panel.Destroy()
        Panel := ""
    }
}

; A click anywhere outside the panel closes it. Armed only once the right-click that opened it is released.
WatchOutside() {
    global PanelArmed
    down := GetKeyState("LButton") || GetKeyState("RButton")
    if !PanelArmed {
        PanelArmed := !down
        return
    }
    if down {
        MouseGetPos(, , &win)
        if (win != Panel.Hwnd)
            ClosePanel()
    }
}

; ---------- button ----------

OnLeftDown(wParam, lParam, msg, hwnd) {
    if TileOf.Has(hwnd) {
        t := TileOf[hwnd]
        if EditMode {
            EditPress(t)
            return 0
        }
        if (t[1].kind = "tab" && DragByTab())
            return 0
        PressTile(t[1], t[2], t[3])
        return 0
    }
    if !IsOurs(hwnd)
        return
    MouseGetPos(&sx, &sy)
    while GetKeyState("LButton") {
        MouseGetPos(&cx, &cy)
        if Abs(cx - sx) > 4 || Abs(cy - sy) > 4 {
            PostMessage(0xA1, 2, 0, Btn)  ; WM_NCLBUTTONDOWN on the caption: Windows drags the window
            return 0
        }
        Sleep(10)
    }
    Toggle()
    return 0
}

OnRightDown(wParam, lParam, msg, hwnd) {
    if !IsOurs(hwnd)
        return
    ShowPanel()
    return 0
}

; Press and slide on a layout tab moves the mic and its grid. False for a plain tap, which then switches layout.
DragByTab() {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&sx, &sy)
    WinGetPos(&bx, &by, , , Btn)
    moved := false
    while GetKeyState("LButton") {
        MouseGetPos(&cx, &cy)
        if (moved || Abs(cx - sx) > 4 || Abs(cy - sy) > 4) {
            moved := true
            Btn.Move(bx + cx - sx, by + cy - sy)  ; the grid follows through WM_MOVE
        }
        Sleep(10)
    }
    if moved
        SavePos()
    return moved
}

IsOurs(hwnd) => hwnd = Btn.Hwnd || hwnd = Icon.Hwnd

; One press = one start or one stop. Presses while Handy is still typing the last result are dropped:
; Handy would queue them and start a new recording by itself as soon as it finished.
Toggle() {
    global LastPress
    if (Engine = "windows") {
        ; Windows shows its own voice typing bar; the button stays blue and does not track it.
        SendEvent("#h")
        return
    }
    if (State = "transcribing" || A_TickCount - LastPress < 800)
        return
    LastPress := A_TickCount
    if !EnsureHandy()
        return
    Run('"' HandyExe '" --toggle-transcription', , "Hide")
    SetState(State = "recording" ? "transcribing" : "recording")
}

SetState(s) {
    global State := s
    Btn.BackColor := (Engine = "windows") ? Colors["windows"] : Colors[s]
    RenderMic()
    ApplyAlpha()
}

; One opacity for the mic and its grid.
ApplyAlpha() {
    a := (Opacity >= 100) ? "Off" : Round(Opacity * 255 / 100)
    WinSetTransparent(a, Btn)
    if Bar
        WinSetTransparent(a, Bar)
}

; Handy logs its tray icon on every state change (tray_idle / tray_recording / tray_transcribing),
; so the button follows Handy's real state, including Ctrl+Space and the Escape cancel.
WatchLog() {
    global LogPos
    try {
        f := FileOpen(HandyLog, "r", "UTF-8")
        size := f.Length
        if (size < LogPos)   ; log was rotated or cleared
            LogPos := 0
        if (size = LogPos) {
            f.Close()
            return
        }
        f.Pos := LogPos
        text := f.Read()
        LogPos := f.Pos
        f.Close()
    } catch
        return
    pos := 1, last := ""
    while (pos := RegExMatch(text, "icon=resources/tray_(idle|recording|transcribing)\.png", &m, pos)) {
        last := m[1]
        pos += m.Len
    }
    if (last != "" && last != State && Engine = "handy")
        SetState(last)
}

ApplySize(first := false) {
    px := Round(Sizes[SizeName] * A_ScreenDPI / 96)
    Btn.SetFont("s" Round(Sizes[SizeName] * 0.36) " cWhite", "Segoe Fluent Icons")
    Icon.SetFont("s" Round(Sizes[SizeName] * 0.36) " cWhite", "Segoe Fluent Icons")
    Icon.Move(0, 0, px, px)
    if first {
        x := IniRead(IniFile, "pos", "x", "")
        y := IniRead(IniFile, "pos", "y", "")
        if (x = "" || y = "") {
            BottomRight(px, &x, &y)
        }
        Btn.Show("x" x " y" y " w" px " h" px " NoActivate" (Hidden ? " Hide" : ""))
    } else {
        Btn.Move(, , px, px)
    }
    WinSetRegion("0-0 w" px " h" px " E", Btn)
    ApplyAlpha()
    BuildBar()
}

PickEngine(label, *) {
    global Engine
    for key, l in Engines
        if (l = label)
            Engine := key
    IniWrite(Engine, IniFile, "engine", "name")
    SetState("idle")
    TrayTip("Dictation: " label, "TouchDock")
}

PickSize(name, *) {
    global SizeName := name
    IniWrite(name, IniFile, "look", "size")
    ApplySize()
}

PickOpacity(pct, *) {
    global Opacity := pct
    IniWrite(pct, IniFile, "look", "opacity")
    ApplyAlpha()
}

ToggleSounds() {
    global KeySounds := !KeySounds
    IniWrite(KeySounds ? 1 : 0, IniFile, "look", "sounds")
}

ToggleHidden() {
    global Hidden := !Hidden
    IniWrite(Hidden ? 1 : 0, IniFile, "look", "hidden")
    Hidden ? Btn.Hide() : Btn.Show("NoActivate")
    BuildBar()
}

; Bottom-right of the work area (above the taskbar) of the screen the mouse is on.
BottomRight(px, &x, &y) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    mon := 1
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (mx >= l && mx < r && my >= t && my < b)
            mon := A_Index
    }
    MonitorGetWorkArea(mon, , , &r, &b)
    margin := Round(24 * A_ScreenDPI / 96)
    x := r - px - margin
    y := b - px - margin
}

ResetPos() {
    WinGetPos(, , &w, , Btn)
    BottomRight(w, &x, &y)
    if Hidden
        ToggleHidden()
    Btn.Move(x, y)
    SavePos()
}

; Back to the saved position, pushed inside the current work area so the mic and its grid stay in view.
; The saved position is kept, so the mic returns there when the screen grows again.
KeepOnScreen() {
    if EditMode
        return
    if Hidden
        return
    WinGetPos(&cx, &cy, &w, &h, Btn)
    x := IniRead(IniFile, "pos", "x", cx), y := IniRead(IniFile, "pos", "y", cy)
    gl := MicAt ? x - MicAt[1] : x, gt := MicAt ? y - MicAt[2] : y
    gw := MicAt ? BarW : w, gh := MicAt ? BarH : h
    MonitorGetWorkArea(MonitorAt(gl + gw // 2, gt + gh // 2), &l, &t, &r, &b)
    dx := (gl < l) ? l - gl : Min(0, r - gl - gw)
    dy := (gt < t) ? t - gt : Min(0, b - gt - gh)
    Btn.Move(x + dx, y + dy)
    ; Always-on-top windows can still end up under another always-on-top window after a screen change.
    if Bar
        WinMoveTop(Bar)
    WinMoveTop(Btn)
}

SavePos() {
    WinGetPos(&wx, &wy, , , Btn)
    IniWrite(wx, IniFile, "pos", "x")
    IniWrite(wy, IniFile, "pos", "y")
}

; ---------- Handy ----------

HandyRunning() => ProcessExist("handy.exe")

EnsureHandy() {
    if !FileExist(HandyExe) {
        MsgBox("Handy not found at`n" HandyExe, "TouchDock", "Icon!")
        return false
    }
    if !HandyRunning() {
        Run('"' HandyExe '"')
        ProcessWait("handy.exe", 10)
        Sleep(1500)
    }
    return true
}

; A second launch is forwarded to the running Handy, which brings its window up.
OpenHandy() {
    if !EnsureHandy()
        return
    Run('"' HandyExe '"')
}

RestartHandy() {
    if HandyRunning() {
        ProcessClose("handy.exe")
        ProcessWaitClose("handy.exe", 10)
    }
    SetState("idle")
    EnsureHandy()
}

CurrentModel() {
    try text := FileRead(HandySettings, "UTF-8")
    catch
        return ""
    return RegExMatch(text, '"selected_model"\s*:\s*"([^"]*)"', &m) ? m[1] : ""
}

; Handy has no command for this, so: close Handy, change "selected_model" in its settings file, start it again.
SwitchModel(name, *) {
    id := Models[name]
    if (id = CurrentModel())
        return
    if HandyRunning() {
        ProcessClose("handy.exe")
        ProcessWaitClose("handy.exe", 10)
    }
    text := FileRead(HandySettings, "UTF-8")
    new := RegExReplace(text, '("selected_model"\s*:\s*")[^"]*(")', "${1}" id "${2}", &n, 1)
    if (n != 1) {
        MsgBox("Could not find the model setting in`n" HandySettings, "TouchDock", "Icon!")
        EnsureHandy()
        return
    }
    f := FileOpen(HandySettings, "w", "UTF-8-RAW")
    f.Write(new)
    f.Close()
    SetState("idle")
    EnsureHandy()
    TrayTip("Model: " name, "TouchDock")
}

ToggleStartup() {
    if FileExist(StartupLink)
        FileDelete(StartupLink)
    else
        FileCreateShortcut(A_IsCompiled ? A_ScriptFullPath : A_AhkPath, StartupLink, A_ScriptDir, A_IsCompiled ? "" : '"' A_ScriptFullPath '"')
}

#Include %A_ScriptDir%\layouts.ahk
#Include %A_ScriptDir%\grid.ahk
#Include %A_ScriptDir%\editor.ahk
#Include %A_ScriptDir%\touchpad.ahk
