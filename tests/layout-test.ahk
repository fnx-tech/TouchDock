#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib.ahk
; layout-test.ahk <buttons file> : prints every layout's grid size and each button's spot and size, as the loader sees them.
ButtonsFile := A_Args[1], LayoutName := "", ButtonsTime := "", EditLayouts := ""
for l in LoadButtons() {
    out := "[" l.name "] " l.cols "x" l.rows "`n"
    for k in l.items
        out .= "  " (k.kind = "mic" ? "Mic" : (k.label != "" ? k.label : k.what)) " @" (k.col + 1) "," (k.row + 1) (k.w != 1 || k.h != 1 ? " " k.w "x" k.h : "") (k.repeat != "" ? " repeat " k.repeat : "") (k.kind = "text" ? " text" : "") (k.sticky ? " sticky" : "") "`n"
    for k in l.off
        out .= "  OFF " (k.label != "" ? k.label : k.what) "`n"
    FileAppend(out, "*")
}
#Include %A_ScriptDir%\..\layouts.ahk
