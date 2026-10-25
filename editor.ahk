; The layout editor for the grid around the mic button. Included by touchdock.ahk, which owns the globals.
; Edit mode works on a copy of the layouts (EditLayouts): Done writes it to layouts.txt, Cancel drops it.
; While editing, the mic button is hidden and drawn as a tile in the grid, and the grid stays at EditPos.

StartEdit() {
    global EditMode, EditLayouts, EditUndo, EditPos, EditStartLayout
    if EditMode
        return
    if Hidden
        ToggleHidden()
    if !ShowBar
        ToggleBar()
    if !Bar
        return TrayTip("No buttons to edit: check layouts.txt", "TouchDock")
    WinGetPos(&x, &y, , , Bar)
    EditPos := [x, y], EditStartLayout := LayoutName
    EditLayouts := LoadButtons(), EditUndo := []
    EditMode := true
    BuildBar()
}

EditDone() {
    lost := ""
    for l in EditLayouts
        for k in l.off
            lost .= "`n   " l.name ":  " (k.label != "" ? k.label : k.what)
    if (lost != "" && Confirm("These buttons are off the grid and will be dropped:" lost "`n`nSave anyway?") != "Yes")
        return
    WriteButtonsFile(EditLayouts, BackupFile)
    IniWrite(LayoutName, IniFile, "look", "layout")
    ; The mic goes where its tile was; the grid follows it from there.
    Btn.Move(EditPos[1] + MicAt[1], EditPos[2] + MicAt[2])
    EndEdit()
    SavePos()
}

EditCancel() {
    global LayoutName := EditStartLayout
    EndEdit()
}

EndEdit() {
    global EditMode := false, EditLayouts := "", EditUndo := []
    ShowEditBox(false)
    ClosePanel()
    ClosePicker()
    Btn.Show("NoActivate")
    BuildBar()
}

; A tap on a tile opens its menu, a tap on "+" adds a button, a press and slide moves the tile by whole spots.
; Runs inside the click on the grid, so anything that rebuilds the grid is started from a timer.
EditPress(t) {
    global LayoutName
    k := t[1]
    if (k.kind = "tab") {
        if !DragBar() {
            LayoutName := k.what
            SetTimer(BuildBar, -1)
        }
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&sx, &sy)
    starts := []
    for ctl in t[2] {
        ctl.GetPos(&cx, &cy)
        starts.Push([cx, cy])
    }
    moved := false, mx := sx, my := sy
    while GetKeyState("LButton") {
        MouseGetPos(&mx, &my)
        if (k.kind != "empty" && (moved || Abs(mx - sx) > 6 || Abs(my - sy) > 6)) {
            moved := true
            for i, ctl in t[2]
                ctl.Move(starts[i][1] + mx - sx, starts[i][2] + my - sy)
        }
        Sleep(10)
    }
    if !moved {
        SetTimer((k.kind = "empty") ? PickButton.Bind(k.col, k.row) : ItemMenu.Bind(k), -1)
        return
    }
    step := G.s + G.gap
    SetTimer(MoveItem.Bind(k, k.col + Round((mx - sx) / step), k.row + Round((my - sy) / step)), -1)
}

; Press and slide on a tab moves the grid while editing. False for a plain tap.
DragBar() {
    global EditPos
    CoordMode("Mouse", "Screen")
    MouseGetPos(&sx, &sy)
    x0 := EditPos[1], y0 := EditPos[2], moved := false
    while GetKeyState("LButton") {
        MouseGetPos(&cx, &cy)
        if (moved || Abs(cx - sx) > 4 || Abs(cy - sy) > 4) {
            moved := true
            EditPos := [x0 + cx - sx, y0 + cy - sy]
            Bar.Move(EditPos[1], EditPos[2])
        }
        Sleep(10)
    }
    if moved
        SetTimer(() => ShowEditBox(true), -1)
    return moved
}

; True when the w x h block at (c, r) is inside the grid and holds nothing but `except`.
SpotFree(l, c, r, w, h, except := "") {
    if (c < 0 || r < 0 || c + w > l.cols || r + h > l.rows)
        return false
    for o in l.items
        if (o != except && c < o.col + o.w && o.col < c + w && r < o.row + o.h && o.row < r + h)
            return false
    return true
}

; Onto free spots it moves; onto a button of the same size in exactly that spot, the two swap.
MoveItem(k, c, r) {
    l := CurLayout()
    if SpotFree(l, c, r, k.w, k.h, k) {
        PushUndo()
        k.col := c, k.row := r
    } else {
        other := ""
        for o in l.items
            if (o != k && o.col = c && o.row = r && o.w = k.w && o.h = k.h)
                other := o
        if other {
            PushUndo()
            other.col := k.col, other.row := k.row, k.col := c, k.row := r
        } else
            Refuse((c < 0 || r < 0 || c + k.w > l.cols || r + k.h > l.rows) ? "Off the grid" : "Something is in the way")
    }
    BuildBar()
}

; Every free spot of the grid shows a "+": tap it to add a button there.
AddEmptySpots(l) {
    used := Map()
    for k in l.items
        loop k.h {
            rr := k.row + A_Index - 1
            loop k.w
                used[rr "," (k.col + A_Index - 1)] := true
        }
    Bar.SetFont("s" Round(G.pt * 0.3) " c707070", "Segoe UI")
    loop l.rows {
        r := A_Index - 1
        loop l.cols {
            c := A_Index - 1
            if used.Has(r "," c)
                continue
            t := Bar.AddText("x" G.gap + c * (G.s + G.gap) " y" G.top + r * (G.s + G.gap) " w" G.s " h" G.s " Center +0x200 +0x100 Background" EmptyColor, "+")
            TileOf[t.Hwnd] := [{kind: "empty", col: c, row: r}, [t], EmptyColor]
        }
    }
}

; ---------- a button's menu ----------

ItemMenu(k) {
    items := []
    if !(k.kind ~= "^(mic|touchpad)$") {
        items.Push(["Name:  " (k.label = "" ? "(icon only)" : k.label) "  …", EditName.Bind(k)])
        if (k.kind = "keys")
            items.Push(["Keys:  " k.what "  …", EditWhat.Bind(k)])
        else if (k.kind = "text")
            items.Push(["Types:  " SubStr(k.what, 1, 24) "  …", EditWhat.Bind(k)])
        else if (k.kind = "open")
            items.Push(["Opens:  " Shorten(k.what) "  …", EditWhat.Bind(k)])
        else if (k.kind = "hold")
            items.Push(["Holds:  " k.what "   " Chr(0x203A), () => ShowPanel(HoldItems(k))])
        if (k.kind = "hold")
            items.Push([Tick(k.HasOwnProp("sticky") && k.sticky) "Sticky (stays on until tapped again)", SetField.Bind(k, "sticky", !(k.HasOwnProp("sticky") && k.sticky))])
        if (k.kind != "open")
            items.Push(["Icon:  " (k.icon = "" ? "none" : k.icon) "  …", EditIcon.Bind(k)])
        if (k.kind = "keys")
            items.Push(["Repeat when held:  " (k.repeat = "" ? "automatic" : k.repeat) "   " Chr(0x203A), () => ShowPanel(RepeatItems(k))])
    }
    items.Push(["Size:  " k.w " wide × " k.h " tall   " Chr(0x203A), () => ShowPanel(SizeItems(k))])
    if (k.kind != "mic") {
        items.Push(["-"])
        items.Push(["Remove", RemoveItem.Bind(k)])
    }
    ShowPanel(items)
}

SizeItems(k) {
    items := [[Chr(0x2039) "  Back", ItemMenu.Bind(k)], ["-"]]
    for h in [1, 2, 3]
        for w in [1, 2, 3]
            items.Push([Tick(k.w = w && k.h = h) w " wide × " h " tall", ResizeItem.Bind(k, w, h)])
    return items
}

HoldItems(k) {
    items := [[Chr(0x2039) "  Back", ItemMenu.Bind(k)], ["-"]]
    for m in ["Ctrl", "Shift", "Alt"]
        items.Push([Tick(k.what = m) m, SetField.Bind(k, "what", m)])
    return items
}

RepeatItems(k) {
    items := [[Chr(0x2039) "  Back", ItemMenu.Bind(k)], ["-"]]
    items.Push([Tick(k.repeat = "") "Automatic (single keys like arrows repeat)", SetField.Bind(k, "repeat", "")])
    items.Push([Tick(k.repeat = "on") "On", SetField.Bind(k, "repeat", "on")])
    items.Push([Tick(k.repeat = "off") "Off", SetField.Bind(k, "repeat", "off")])
    return items
}

SetField(k, field, value) {
    PushUndo()
    k.%field% := value
    BuildBar()
}

ResizeItem(k, w, h) {
    if !SpotFree(CurLayout(), k.col, k.row, w, h, k)
        return Refuse("No room: move or remove what is in the way first")
    PushUndo()
    k.w := w, k.h := h
    BuildBar()
}

RemoveItem(k) {
    l := CurLayout()
    for i, o in l.items
        if (o = k) {
            PushUndo()
            l.items.RemoveAt(i)
            break
        }
    BuildBar()
}

EditName(k) {
    v := Ask("Name on the button (leave empty for an icon-only button):", k.label, &ok)
    if !ok
        return
    v := StrReplace(Trim(v), "|")
    if (v = "" && k.icon = "" && k.kind != "open")
        return Refuse("Give it a name or an icon")
    SetField(k, "label", v)
}

EditWhat(k) {
    if (k.kind = "keys")
        v := Ask(KeysPrompt(), k.what, &ok, 210)
    else if (k.kind = "text")
        v := Ask("Text to type:", k.what, &ok)
    else
        v := Ask("Program, file, folder or web address to open:", k.what, &ok)
    v := StrReplace(Trim(v), "|")
    if (!ok || v = "")
        return
    SetField(k, "what", v)
}

KeysPrompt() => "Keys to press, in AutoHotkey names:`n^c = Ctrl+C     +{End} = Shift+End     !{Tab} = Alt+Tab     #d = Win+D`nSeveral in a row: separate them with spaces, e.g.  {Home} +{End}"

EditIcon(k) {
    v := Ask("Icon: a 4-character code from the Segoe Fluent Icons font (E8C8 is Copy).`nLeave empty for no icon.", k.icon, &ok, 180)
    if !ok
        return
    v := Trim(v)
    if (v != "" && !(v ~= "i)^[0-9a-f]{4}$"))
        return Refuse("An icon code is 4 characters, 0-9 and A-F")
    if (v = "" && k.label = "")
        return Refuse("Give it a name or an icon")
    SetField(k, "icon", StrUpper(v))
}

; ---------- grid size and layouts ----------

ResizeGrid(dc, dr, *) {
    l := CurLayout()
    nc := l.cols + dc, nr := l.rows + dr
    if (nc < 1 || nr < 1)
        return
    for k in l.items
        if (k.kind = "mic" && (k.col + k.w > nc || k.row + k.h > nr))
            return Refuse("The mic is in the way: move it first")
    PushUndo()
    keep := []
    for k in l.items {
        if (k.col + k.w <= nc && k.row + k.h <= nr)
            keep.Push(k)
        else
            k.col := k.row := -1, l.off.Push(k)  ; offered again under "Off the grid" when adding a button
    }
    l.items := keep, l.cols := nc, l.rows := nr
    BuildBar()
}

AskLayoutName(prompt, def := "") {
    v := Ask(prompt, def, &ok)
    v := Trim(StrReplace(StrReplace(StrReplace(v, "[", ""), "]", ""), "|", ""))
    if (!ok || v = "")
        return ""
    for l in EditLayouts
        if (l.name = v) {
            Refuse("There is already a layout called " v)
            return ""
        }
    return v
}

EditNewLayout() {
    global LayoutName
    cur := CurLayout()
    name := AskLayoutName("Name of the new layout:")
    if (name = "")
        return
    PushUndo()
    items := []
    for k in cur.items
        if (k.kind = "mic")
            items.Push(k.Clone())  ; the same mic spot, so the grid does not jump when switching
    EditLayouts.Push({name: name, cols: cur.cols, rows: cur.rows, items: items, off: []})
    LayoutName := name
    BuildBar()
}

EditDuplicateLayout() {
    global LayoutName
    cur := CurLayout()
    name := AskLayoutName("Name of the copy:", cur.name " copy")
    if (name = "")
        return
    PushUndo()
    copy := CloneLayouts([CurLayout()])[1]
    copy.name := name
    for i, l in EditLayouts
        if (l.name = cur.name) {
            EditLayouts.InsertAt(i + 1, copy)
            break
        }
    LayoutName := name
    BuildBar()
}

EditRenameLayout() {
    global LayoutName
    cur := CurLayout()
    name := AskLayoutName("New name for " cur.name ":", cur.name)
    if (name = "")
        return
    PushUndo()
    CurLayout().name := name
    LayoutName := name
    BuildBar()
}

EditDeleteLayout() {
    global LayoutName
    if (EditLayouts.Length = 1)
        return Refuse("This is the only layout")
    cur := CurLayout()
    if (Confirm("Delete the layout " cur.name " and its buttons?") != "Yes")
        return
    PushUndo()
    for i, l in EditLayouts
        if (l.name = cur.name) {
            EditLayouts.RemoveAt(i)
            break
        }
    LayoutName := EditLayouts[1].name
    BuildBar()
}

PushUndo() {
    EditUndo.Push(CloneLayouts(EditLayouts))
    if (EditUndo.Length > 50)
        EditUndo.RemoveAt(1)
}

EditUndoStep() {
    global EditLayouts, LayoutName
    if !EditUndo.Length
        return Refuse("Nothing to undo")
    EditLayouts := EditUndo.Pop()
    LayoutName := CurLayout().name  ; the undone step may have renamed or removed the current layout
    BuildBar()
}

; ---------- the editor's side panel ----------

; Done, Cancel, Undo, grid size and layouts, beside the grid.
ShowEditBox(show) {
    global EditBox
    if EditBox
        EditBox.Destroy(), EditBox := ""
    if (!show || !Bar)
        return
    l := CurLayout()
    pt := Round(Sizes[SizeName] * 0.14)
    scale := A_ScreenDPI / 96
    rowH := Round(pt * 2.6 * scale), w := Round(pt * 17 * scale)
    EditBox := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +Border +E0x08000000", "TouchDock Editor")
    EditBox.BackColor := "202020"
    EditBox.MarginX := 0, EditBox.MarginY := 0
    EditBox.SetFont("s" pt " cF0F0F0", "Segoe UI")
    rows := [["Done (save)", EditDone, TilePressed], ["Cancel", EditCancel], ["Undo", EditUndoStep], ["-"],
        ["Columns", l.cols, ResizeGrid.Bind(-1, 0), ResizeGrid.Bind(1, 0)],
        ["Rows", l.rows, ResizeGrid.Bind(0, -1), ResizeGrid.Bind(0, 1)], ["-"],
        ["New layout  …", EditNewLayout], ["Duplicate layout  …", EditDuplicateLayout],
        ["Rename layout  …", EditRenameLayout], ["Delete layout", EditDeleteLayout]]
    y := 0
    for it in rows {
        if (it[1] = "-") {
            EditBox.AddText("x0 y" y + Round(rowH * 0.15) " w" w " h1 Background505050")
            y += Round(rowH * 0.3)
            continue
        }
        if (it.Length = 4) {  ; a count with − and + beside it
            third := w // 6
            EditBox.AddText("x0 y" y " w" w - 3 * third " h" rowH " +0x200 Background202020", "   " it[1])
            EditBox.AddText("x" w - 3 * third " y" y " w" third " h" rowH " Center +0x200 Background333333", Chr(0x2212)).OnEvent("Click", EditAction.Bind(it[3]))
            EditBox.AddText("x" w - 2 * third " y" y " w" third " h" rowH " Center +0x200 Background202020", it[2])
            EditBox.AddText("x" w - third " y" y " w" third " h" rowH " Center +0x200 Background333333", "+").OnEvent("Click", EditAction.Bind(it[4]))
        } else {
            color := (it.Length >= 3) ? it[3] : "202020"
            EditBox.AddText("x0 y" y " w" w " h" rowH " +0x200 Background" color, "   " it[1]).OnEvent("Click", EditAction.Bind(it[2]))
        }
        y += rowH
    }
    ; Beside the grid, on whichever side has room.
    WinGetPos(&gx, &gy, &gw, &gh, Bar)
    MonitorGetWorkArea(MonitorAt(gx + gw // 2, gy + gh // 2), &ml, &mt, &mr, &mb)
    x := (gx - w - 8 >= ml) ? gx - w - 8 : gx + gw + 8
    EditBox.Show("x" x " y" Min(Max(gy, mt), mb - y) " w" w " h" y " NoActivate")
}

; From a timer: the action may rebuild the window whose click is being handled.
EditAction(fn, *) => SetTimer(fn, -1)

; ---------- adding a button ----------

PickButton(c, r) {
    global Picker
    ClosePicker()
    entries := []
    entries.Push({group: "Your own", label: "Keys you choose  …", custom: "keys"})
    entries.Push({group: "Your own", label: "Text to type  …", custom: "text"})
    entries.Push({group: "Your own", label: "Program, file or web address  …", custom: "open"})
    for k in CurLayout().off
        entries.Push({group: "Off the grid", label: (k.label != "" ? k.label : k.what), item: k, kind: k.kind, what: k.what})
    for e in BuiltinButtons()
        entries.Push(e)
    for e in StartMenuPrograms()
        entries.Push(e)

    Picker := Gui("+AlwaysOnTop +ToolWindow", "Add a button")
    Picker.SetFont("s13", "Segoe UI")
    Picker.AddText("y+12", "Find:")
    find := Picker.AddEdit("x+8 yp-4 w420")
    lv := Picker.AddListView("xm w520 h460 -Multi", ["Button", "Group", "Does"])
    il := IL_Create(entries.Length + 1)
    lv.SetImageList(il)
    imgs := Map()
    for e in entries
        if (e.HasOwnProp("kind") && e.kind = "open" && (h := FileIcon(e.what))) {
            imgs[e] := IL_Add(il, "HICON:*" h)
            DllCall("DestroyIcon", "Ptr", h)
        }
    add := Picker.AddButton("xm w250 h44 Default", "Add")
    Picker.AddButton("x+20 w250 h44", "Cancel").OnEvent("Click", (*) => ClosePicker())
    shown := []

    Fill(*) {
        lv.Opt("-Redraw")
        lv.Delete()
        shown.Length := 0
        q := find.Value
        for e in entries {
            name := e.HasOwnProp("pickName") ? e.pickName : e.label
            if (q != "" && !InStr(name " " e.group, q))
                continue
            lv.Add("Icon" (imgs.Has(e) ? imgs[e] : 0), name, e.group, Describe(e))
            shown.Push(e)
        }
        lv.ModifyCol(1, 220), lv.ModifyCol(2, 110), lv.ModifyCol(3, 170)
        lv.Opt("+Redraw")
    }
    Choose(*) {
        row := lv.GetNext()
        if !row
            return
        e := shown[row]
        ClosePicker()
        SetTimer(AddFromPicker.Bind(e, c, r), -1)
    }
    find.OnEvent("Change", Fill)
    lv.OnEvent("DoubleClick", Choose)
    add.OnEvent("Click", Choose)
    Picker.OnEvent("Close", (*) => ClosePicker())
    Picker.OnEvent("Escape", (*) => ClosePicker())
    Fill()
    Picker.Show()
}

ClosePicker() {
    global Picker
    if Picker
        Picker.Destroy(), Picker := ""
}

Describe(e) {
    if e.HasOwnProp("custom")
        return ""
    switch e.kind {
        case "open": return Shorten(e.what)
        case "hold": return "held for the next key"
        case "touchpad": return "moves the pointer, tap to click"
        case "text": return "types " SubStr(e.what, 1, 20)
        default: return e.what
    }
}

Shorten(path) {
    SplitPath(path, &name)
    return (name != "") ? RegExReplace(name, "i)\.lnk$") : path
}

AddFromPicker(e, c, r) {
    l := CurLayout()
    if e.HasOwnProp("custom") {
        k := CustomButton(e.custom)
        if !k
            return
    } else if e.HasOwnProp("item") {
        k := e.item
    } else {
        k := {label: e.label, kind: e.kind, what: e.what, icon: e.icon, col: -1, row: -1, w: 1, h: 1, repeat: ""}
    }
    PushUndo()
    if e.HasOwnProp("item")
        for i, o in l.off
            if (o = k) {
                l.off.RemoveAt(i)
                break
            }
    if (k.kind = "touchpad")  ; a pad starts as big as fits, up to 3 x 2
        for wh in [[3, 2], [2, 2], [2, 1], [1, 1]]
            if SpotFree(l, c, r, wh[1], wh[2]) {
                k.w := wh[1], k.h := wh[2]
                break
            }
    if !SpotFree(l, c, r, k.w, k.h)
        k.w := 1, k.h := 1  ; a button back from off the grid shrinks to one spot when its old size does not fit
    k.col := c, k.row := r
    l.items.Push(k)
    BuildBar()
}

CustomButton(kind) {
    name := Ask("Name on the button:", "", &ok)
    if !ok
        return ""
    name := StrReplace(Trim(name), "|")
    if (kind = "keys")
        v := Ask(KeysPrompt(), "", &ok, 210)
    else if (kind = "text")
        v := Ask("Text to type:", "", &ok)
    else
        v := Ask("Program, file, folder or web address to open:", "", &ok)
    v := StrReplace(Trim(v), "|")
    if (!ok || v = "")
        return ""
    if (name = "")
        name := (kind = "open") ? Shorten(v) : v
    return {label: name, kind: kind, what: v, icon: "", col: -1, row: -1, w: 1, h: 1, repeat: ""}
}

; The ready-made buttons offered when adding one.
BuiltinButtons() {
    static list := ""
    if list
        return list
    data := [
        ["Edit", "Cut", "keys", "^x", "E8C6"], ["Edit", "Copy", "keys", "^c", "E8C8"], ["Edit", "Paste", "keys", "^v", "E77F"],
        ["Edit", "Clips", "keys", "^!v", "E81C"], ["Edit", "Select all", "keys", "^a", "E8B3"],
        ["Edit", "Undo", "keys", "^z", "E7A7"], ["Edit", "Redo", "keys", "^y", "E7A6"],
        ["Edit", "Backspace", "keys", "{BS}", "E750"], ["Edit", "Delete", "keys", "{Del}"], ["Edit", "Enter", "keys", "{Enter}", "E751"],
        ["Edit", "Clipboard history", "keys", "#v"], ["Edit", "Emoji", "keys", "#."],
        ["Modifier", "Ctrl", "hold", "Ctrl"], ["Modifier", "Shift", "hold", "Shift"], ["Modifier", "Alt", "hold", "Alt"],
        ["Keys", "Esc", "keys", "{Esc}"], ["Keys", "Tab", "keys", "{Tab}"], ["Keys", "Space", "keys", "{Space}"],
        ["Keys", "Home", "keys", "{Home}"], ["Keys", "End", "keys", "{End}"],
        ["Keys", "PgUp", "keys", "{PgUp}"], ["Keys", "PgDn", "keys", "{PgDn}"], ["Keys", "Insert", "keys", "{Ins}"],
        ["Keys", "", "keys", "{Up}", "E74A"], ["Keys", "", "keys", "{Down}", "E74B"],
        ["Keys", "", "keys", "{Left}", "E72B"], ["Keys", "", "keys", "{Right}", "E72A"],
        ["Keys", "PrtSc", "keys", "{PrintScreen}"], ["Keys", "Touchpad", "touchpad", ""],
        ["Shortcuts", "Save", "keys", "^s", "E74E"], ["Shortcuts", "Find", "keys", "^f", "E721"],
        ["Shortcuts", "New tab", "keys", "^t", "E710"], ["Shortcuts", "Close tab", "keys", "^w", "E711"],
        ["Shortcuts", "Reopen tab", "keys", "^+t"], ["Shortcuts", "Next tab", "keys", "^{Tab}"], ["Shortcuts", "Previous tab", "keys", "^+{Tab}"],
        ["Shortcuts", "Switch app", "keys", "!{Tab}"], ["Shortcuts", "Task view", "keys", "#{Tab}"],
        ["Shortcuts", "Desktop", "keys", "#d"], ["Shortcuts", "Snip", "keys", "#+s"], ["Shortcuts", "Explorer", "keys", "#e"],
        ["Shortcuts", "Rename", "keys", "{F2}", "E8AC"], ["Shortcuts", "Refresh", "keys", "{F5}", "E72C"],
        ["Shortcuts", "Close app", "keys", "!{F4}"], ["Shortcuts", "Task manager", "open", A_WinDir "\System32\Taskmgr.exe"], ["Shortcuts", "Lock PC", "keys", "#l"],
        ["Shortcuts", "Zoom in", "keys", "^=", "E8A3"], ["Shortcuts", "Zoom out", "keys", "^-", "E71F"]
    ]
    ; Arrows have no name on their tile; the picker still needs one to show.
    names := Map("{Up}", "Up arrow", "{Down}", "Down arrow", "{Left}", "Left arrow", "{Right}", "Right arrow")
    list := []
    for d in data {
        e := {group: d[1], label: d[2], kind: d[3], what: d[4], icon: (d.Length >= 5) ? d[5] : ""}
        if names.Has(e.what)
            e.pickName := names[e.what]
        list.Push(e)
    }
    loop 12
        list.Push({group: "Keys", label: "F" A_Index, kind: "keys", what: "{F" A_Index "}", icon: ""})
    return list
}

; Programs from the Start menu (yours and everyone's), by name.
StartMenuPrograms() {
    static list := ""
    if list
        return list
    seen := Map(), names := ""
    for dir in [A_StartMenu, A_StartMenuCommon]
        loop files dir "\*.lnk", "R" {
            name := RegExReplace(A_LoopFileName, "i)\.lnk$")
            if (seen.Has(name) || name ~= "i)uninstall|readme|release notes|help|website|documentation")
                continue
            seen[name] := A_LoopFileFullPath
            names .= name "`n"
        }
    list := []
    if (names != "")
        for n in StrSplit(Sort(RTrim(names, "`n")), "`n")
            list.Push({group: "Programs", label: n, kind: "open", what: seen[n], icon: ""})
    return list
}

; ---------- small dialogs ----------

; An input box over the always-on-top grid: the grid steps back while it is open. ok is false on Cancel.
Ask(prompt, def, &ok, h := 150) {
    for g in [Bar, EditBox]
        if g
            g.Opt("-AlwaysOnTop")
    r := InputBox(prompt, "Edit layout", "W480 H" h, def)
    for g in [Bar, EditBox]
        if g
            try g.Opt("+AlwaysOnTop")
    ok := (r.Result = "OK")
    return r.Value
}

Confirm(text) => MsgBox(text, "Edit layout", 4 + 48 + 0x40000)  ; Yes/No, warning icon, always on top

Refuse(msg) {
    global LastRefusal := msg
    CoordMode("Mouse", "Screen"), CoordMode("ToolTip", "Screen")
    MouseGetPos(&x, &y)
    ToolTip(msg, x + 16, y + 16)
    SetTimer(() => ToolTip(), -2000)
}
