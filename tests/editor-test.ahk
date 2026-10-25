; editor-test.ahk : drives the layout editor without the mouse. Copied next to touchdock.ahk as
; zz-editor-test.ahk by editor-test.sh (so the script's own paths work), on a copy of layouts.txt.
#Include %A_ScriptDir%\touchdock.ahk
OnError((e, *) => (FileAppend("ERROR: " e.Message " (" e.What ", " e.File ":" e.Line ")`n", "*"), ExitApp(2)))
Say(s) => FileAppend(s "`n", "*")
Check(name, ok) => Say((ok ? "ok    " : "FAIL  ") name)
Find(l, label) {
    for k in l.items
        if (k.label = label || k.what = label)
            return k
}
Spots(l) {
    s := ""
    for k in SortedBySpot(l.items)
        s .= k.label k.what "@" k.col "," k.row " " k.w "x" k.h ";"
    return s
}

ButtonsFile := A_ScriptDir "\tests\editor-copy.txt", BackupFile := A_ScriptDir "\tests\editor-copy.bak"
LayoutName := "Edit"
BuildBar()
StartEdit()
l := CurLayout()
Check("edit mode on", EditMode && Bar && EditBox && !DllCall("IsWindowVisible", "Ptr", Btn.Hwnd))
plus := 0
for h, t in TileOf
    plus += (t[1].kind = "empty")
used := 0
for k in l.items
    used += k.w * k.h
Check("a + on every free spot (" plus ")", plus = l.cols * l.rows - used)
start := Spots(l)

cut := Find(l, "Cut"), copy := Find(l, "Copy"), paste := Find(l, "Paste"), ctrl := Find(l, "Ctrl")
MoveItem(cut, 3, 2)
Check("move onto a free spot", cut.col = 3 && cut.row = 2)
MoveItem(copy, 2, 0)
Check("swap with a same-size button", copy.col = 2 && paste.col = 1)
LastRefusal := "", MoveItem(ctrl, 4, 2)
Check("move onto the mic refused: " LastRefusal, LastRefusal != "" && ctrl.col = 0 && ctrl.row = 1)
EditUndoStep(), EditUndoStep()
Check("undo twice gives the start back", Spots(CurLayout()) = start)

l := CurLayout(), copy := Find(l, "Copy")
LastRefusal := "", ResizeItem(copy, 2, 1)
Check("size refused when blocked: " LastRefusal, LastRefusal != "" && copy.w = 1)
RemoveItem(copy)
Check("remove", !Find(CurLayout(), "Copy"))
EditUndoStep()
Check("undo remove", Find(CurLayout(), "Copy"))

LastRefusal := "", ResizeGrid(-1, 0)
Check("shrinking into the mic refused: " LastRefusal, LastRefusal != "" && CurLayout().cols = 6)
ResizeGrid(1, 1)
Check("grid grows", CurLayout().cols = 7 && CurLayout().rows = 5)
l := CurLayout(), bs := Find(l, "Backspace"), MoveItem(bs, 6, 0)
ResizeGrid(-1, 0)
Check("button cut off goes off the grid", CurLayout().off.Length = 1 && CurLayout().cols = 6)
AddFromPicker({group: "Off the grid", label: "Backspace", item: CurLayout().off[1], kind: "keys", what: "{BS}"}, 4, 0)
Check("off-grid button added back", CurLayout().off.Length = 0 && Find(CurLayout(), "Backspace").col = 4)
ResizeGrid(0, -1)
Check("grid back to 6x4", CurLayout().cols = 6 && CurLayout().rows = 4)

n := CurLayout().items.Length
AddFromPicker(BuiltinButtons()[1], 3, 2)
added := CurLayout().items[CurLayout().items.Length]
Check("add Cut from the picker list into an empty spot", CurLayout().items.Length = n + 1 && added.label = "Cut" && added.col = 3 && added.row = 2)
RemoveItem(added)
big := Find(CurLayout(), "Select all")
ResizeItem(big, 2, 1)
Check("2x1 button", big.w = 2 && big.col = 2)

AddFromPicker({group: "Keys", label: "Touchpad", kind: "touchpad", what: "", icon: ""}, 5, 0)
pad := CurLayout().items[CurLayout().items.Length]
Check("touchpad added at the free spot (" pad.w "x" pad.h ")", pad.kind = "touchpad" && pad.col = 5 && pad.row = 0)
ResizeItem(pad, 1, 2)
Check("touchpad resized to 1x2", pad.w = 1 && pad.h = 2)

PickButton(3, 3)
Check("picker opens with programs", Picker && StartMenuPrograms().Length > 0)
ClosePicker()

before := FileRead(ButtonsFile)
micX := EditPos[1] + MicAt[1], micY := EditPos[2] + MicAt[2]
EditDone()
Check("done: edit mode off, mic back", !EditMode && DllCall("IsWindowVisible", "Ptr", Btn.Hwnd))
WinGetPos(&bx, &by, , , Btn)
Check("mic where its tile was", bx = micX && by = micY)
Check("backup is the file before", FileRead(BackupFile) = before)
saved := LoadButtons()
Check("saved file loads to what was on screen", InStr(Spots(CurLayout(saved)), "Select all^a@2,2 2x1"))
Check("saved touchpad loads back", InStr(Spots(CurLayout(saved)), "Touchpad@5,0 1x2"))
StartEdit(), MoveItem(Find(CurLayout(), "Ctrl"), 3, 3), EditCancel()
Check("cancel keeps the file", FileRead(ButtonsFile) = FileRead(ButtonsFile) && !InStr(Spots(CurLayout(LoadButtons())), "Ctrl@3,3"))
ExitApp()
