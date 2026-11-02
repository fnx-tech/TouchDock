#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; save-test.ahk <buttons file> : loads the file, saves it back through the editor's writer, loads it again,
; and prints whether every spot, size, sticky flag and off-grid button survived, and whether the writer
; dropped lines the loader skipped or notes below the top block. The file is changed; run it on a copy.
ButtonsFile := A_Args[1], LayoutName := "", ButtonsTime := "", EditLayouts := ""
Dump(ls) {
    s := ""
    for l in ls {
        s .= "[" l.name "] " l.cols "x" l.rows " off " l.off.Length "`n"
        for k in SortedBySpot(l.items)
            s .= "  " k.kind "|" k.label "|" k.what "|" k.icon "|" k.col "," k.row "|" k.w "x" k.h "|" k.repeat "|" (k.HasOwnProp("sticky") && k.sticky) "`n"
    }
    return s
}
before := LoadButtons()
skipped := LoadSkipped, notes := LoadNotes
WriteButtonsFile(before, ButtonsFile ".bak")
after := LoadButtons()
if skipped
    FileAppend("round trip: DIFFERENT, " skipped " skipped line(s) are lost`n", "*")
else if notes
    FileAppend("round trip: DIFFERENT, " notes " note(s) below the top block are lost`n", "*")
else
    FileAppend((Dump(before) = Dump(after) ? "round trip: same`n" : "round trip: DIFFERENT`n" Dump(before) "---`n" Dump(after)), "*")
#Include %A_ScriptDir%\..\layouts.ahk
