#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; save-test.ahk <buttons file> : loads the file, saves it back through the editor's writer, loads it again,
; and prints whether every spot and size survived. The file is changed; run it on a copy.
ButtonsFile := A_Args[1], LayoutName := "", ButtonsTime := "", EditLayouts := ""
Dump(ls) {
    s := ""
    for l in ls {
        s .= "[" l.name "] " l.cols "x" l.rows "`n"
        for k in SortedBySpot(l.items)
            s .= "  " k.kind "|" k.label "|" k.what "|" k.icon "|" k.col "," k.row "|" k.w "x" k.h "|" k.repeat "`n"
    }
    return s
}
before := LoadButtons()
WriteButtonsFile(before, ButtonsFile ".bak")
after := LoadButtons()
FileAppend((Dump(before) = Dump(after) ? "round trip: same`n" : "round trip: DIFFERENT`n" Dump(before) "---`n" Dump(after)), "*")
#Include %A_ScriptDir%\..\layouts.ahk
