; Reading layouts.txt into layouts: every button gets a spot and a size. No windows here, so tests can include it alone.

; Layouts of layouts.txt, each {name, cols, rows, items, off}. Every item has a spot (col, row, 0-based)
; and a size (w, h) in tiles; "off" holds buttons that did not fit the grid. Bad lines are skipped and named.
LoadButtons() {
    global ButtonsTime
    layouts := [], bad := [], cols := 4
    cur := {name: "", cols: cols, rows: 0, items: [], off: []}
    try {
        ButtonsTime := FileGetTime(ButtonsFile, "M")
        text := FileRead(ButtonsFile, "UTF-8")
    } catch {
        TrayTip("No layouts.txt found", "TouchDock")
        return layouts
    }
    for n, line in StrSplit(text, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        if RegExMatch(line, "^\[(.+)\]$", &m) {
            if (cur.name != "" || cur.items.Length)
                layouts.Push(cur)
            cur := {name: Trim(m[1]), cols: cols, rows: 0, items: [], off: []}
            continue
        }
        if (line ~= "^-+$") {
            cur.items.Push({kind: "row"})
            continue
        }
        if RegExMatch(line, "i)^columns\s*=\s*(\d+)$", &m) {
            cur.cols := Max(1, Integer(m[1]))
            if (cur.name = "")  ; before the first [layout]: the default for every layout
                cols := cur.cols
            continue
        }
        if RegExMatch(line, "i)^grid\s*=\s*(\d+)\s*x\s*(\d+)$", &m) {
            cur.cols := Max(1, Integer(m[1])), cur.rows := Max(1, Integer(m[2]))
            continue
        }
        k := ParseButton(line)
        if k
            cur.items.Push(k)
        else
            bad.Push(n)
    }
    if (cur.name != "" || cur.items.Length)
        layouts.Push(cur)
    if bad.Length {
        s := ""
        for n in bad
            s .= (s = "" ? "" : ", ") n
        TrayTip("layouts.txt: skipped line " s, "TouchDock")
    }
    for l in layouts
        ResolveLayout(l)
    return layouts
}

; Label | kind | what, then any of: an icon code, "at C,R", "size WxH", "repeat on/off".
; The mic and touchpad lines have no "what":  Mic | mic | at C,R | size WxH.  Returns "" for a bad line.
ParseButton(line) {
    f := StrSplit(line, "|", " `t")
    if (f.Length < 2)
        return ""
    kind := StrLower(f[2])
    k := {label: f[1], kind: kind, what: "", icon: "", col: -1, row: -1, w: 1, h: 1, repeat: "", sticky: false}
    if (kind = "mic" || kind = "touchpad") {
        k.w := 2, k.h := 2, first := 3
    } else {
        if (f.Length < 3 || f[3] = "" || !(kind ~= "^(keys|open|hold|text)$"))
            return ""
        k.what := f[3], first := 4
    }
    loop Max(0, f.Length - first + 1) {
        v := f[first + A_Index - 1]
        if (v = "")
            continue
        if (v ~= "i)^[0-9a-f]{4}$")
            k.icon := v
        else if RegExMatch(v, "i)^at\s+(\d+)\s*,\s*(\d+)$", &m)
            k.col := Integer(m[1]) - 1, k.row := Integer(m[2]) - 1
        else if RegExMatch(v, "i)^size\s+(\d+)\s*x\s*(\d+)$", &m)
            k.w := Max(1, Integer(m[1])), k.h := Max(1, Integer(m[2]))
        else if RegExMatch(v, "i)^repeat\s+(on|off)$", &m)
            k.repeat := StrLower(m[1])
        else if (kind = "hold" && v = "sticky")
            k.sticky := true
        else
            return ""
    }
    if (kind = "hold") {
        if !(k.what ~= "i)^(ctrl|shift|alt)$")
            return ""
        k.what := Format("{:T}", k.what)
    }
    if !(kind ~= "^(mic|touchpad|open)$") && k.label = "" && k.icon = ""
        return ""
    return k
}

; Gives every item a spot: buttons with "at" first, then the rest in file order into the next free spots
; ("-" ends a row). Without a mic line the mic gets the bottom 2 x 2 of one extra column on the right.
ResolveLayout(l) {
    used := Map(), placed := [], off := l.off, cols := l.cols, rows := l.rows

    Free(c, r, w, h) {
        if (c < 0 || r < 0 || c + w > cols || (rows && r + h > rows))
            return false
        loop h {
            rr := r + A_Index - 1
            loop w
                if used.Has(rr "," (c + A_Index - 1))
                    return false
        }
        return true
    }
    Take(k, c, r) {
        k.col := c, k.row := r
        loop k.h {
            rr := r + A_Index - 1
            loop k.w
                used[rr "," (c + A_Index - 1)] := k
        }
        placed.Push(k)
    }

    flow := []
    for k in l.items {
        if (k.kind != "row" && k.col >= 0 && Free(k.col, k.row, k.w, k.h))
            Take(k, k.col, k.row)
        else
            flow.Push(k)
    }
    r := 0, c := 0
    for k in flow {
        if (k.kind = "row") {
            if (c > 0)
                r++, c := 0
            continue
        }
        tr := r, tc := c, fits := k.w <= cols
        while fits {
            if (tc + k.w > cols)
                tr++, tc := 0
            if (rows && tr + k.h > rows)
                fits := false
            else if Free(tc, tr, k.w, k.h)
                break
            else
                tc++
        }
        if !fits {
            k.col := k.row := -1
            off.Push(k)
            continue
        }
        Take(k, tc, tr)
        r := tr, c := tc + k.w
    }

    hasMic := false, last := 0
    for k in placed {
        hasMic := hasMic || k.kind = "mic"
        last := Max(last, k.row + k.h)
    }
    if !hasMic {
        i := off.Length  ; a mic that did not fit its spot is placed here instead
        while (i >= 1) {
            if (off[i].kind = "mic")
                off.RemoveAt(i)
            i--
        }
        mic := {label: "Mic", kind: "mic", what: "", icon: "", col: -1, row: -1, w: 2, h: 2, repeat: ""}
        bottom := Max(rows ? rows : last, 2)
        cols += 1
        if !Free(cols - 2, bottom - 2, 2, 2)
            cols += 1
        if !rows
            rows := bottom
        Take(mic, cols - 2, bottom - 2)
        last := Max(last, bottom)
    }
    l.cols := cols, l.rows := rows ? rows : Max(last, 1)
    l.items := placed, l.off := off
}

; The layout picked on the tabs, from the given layouts or the editor's copy.
CurLayout(layouts := "") {
    if !layouts
        layouts := EditLayouts
    for l in layouts
        if (l.name = LayoutName)
            return l
    return layouts[1]
}

; ---------- saving ----------

; Keeps the notes block at the top of the file, writes every layout with each button's spot and size,
; and keeps the file as it was before as backup.
WriteButtonsFile(layouts, backup) {
    head := ""
    try {
        for line in StrSplit(FileRead(ButtonsFile, "UTF-8"), "`n", "`r") {
            if (Trim(line) != "" && SubStr(Trim(line), 1, 1) != "#")
                break
            head .= line "`r`n"
        }
    }
    out := RTrim(head, "`r`n") "`r`n"
    for l in layouts {
        out .= "`r`n[" l.name "]`r`ngrid = " l.cols " x " l.rows "`r`n"
        for k in SortedBySpot(l.items)
            out .= ButtonLine(k) "`r`n"
    }
    try FileCopy(ButtonsFile, backup, true)
    f := FileOpen(ButtonsFile, "w", "UTF-8-RAW")
    f.Write(out)
    f.Close()
}

ButtonLine(k) {
    at := " | at " (k.col + 1) "," (k.row + 1)
    size := (k.w != 1 || k.h != 1 || k.kind = "mic") ? " | size " k.w "x" k.h : ""
    if (k.kind = "mic")
        return Format("{:-10}", "Mic") " | mic" at size
    if (k.kind = "touchpad")
        return Format("{:-10}", "Touchpad") " | touchpad" at " | size " k.w "x" k.h
    line := Format("{:-10}", k.label) " | " k.kind " | " k.what
    if (k.icon != "")
        line .= " | " k.icon
    line .= at size
    if (k.repeat != "")
        line .= " | repeat " k.repeat
    if (k.HasOwnProp("sticky") && k.sticky)
        line .= " | sticky"
    return line
}

; Top row first, left to right.
SortedBySpot(items) {
    out := items.Clone()
    loop out.Length - 1 {
        i := A_Index + 1, k := out[i], j := i - 1
        while (j >= 1 && (out[j].row > k.row || (out[j].row = k.row && out[j].col > k.col))) {
            out[j + 1] := out[j]
            j--
        }
        out[j + 1] := k
    }
    return out
}

CloneLayouts(ls) {
    out := []
    for l in ls {
        items := [], off := []
        for k in l.items
            items.Push(k.Clone())
        for k in l.off
            off.Push(k.Clone())
        out.Push({name: l.name, cols: l.cols, rows: l.rows, items: items, off: off})
    }
    return out
}
