; Automatic and manual update checking against GitHub releases.
; Included by touchdock.ahk, which owns the globals.

CheckUpdatesQuiet() {
    if !FileExist(IniFile)
        return
    last := IniRead(IniFile, "update", "lastcheck", "")
    try recent := (last != "" && DateDiff(A_Now, last, "Hours") < 24)
    catch
        recent := false  ; a hand-edited, unreadable date
    if recent
        return
    CheckForUpdates(false)
}

CheckUpdatesManual(*) {
    CheckForUpdates(true)
}

CheckForUpdates(manual := false) {
    static busy := false
    if busy
        return
    busy := true
    try IniWrite(A_Now, IniFile, "update", "lastcheck")  ; a read-only folder must not stop the check
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(4000, 4000, 6000, 6000)
        req.Open("GET", "https://api.github.com/repos/fnx-tech/TouchDock/releases/latest", true)
        req.SetRequestHeader("User-Agent", "TouchDock")
        req.Send()
        ; Asynchronous and polled with Sleep, so the dock keeps answering touches while the request runs.
        deadline := A_TickCount + 30000
        while !req.WaitForResponse(0) {
            if (A_TickCount > deadline)
                throw Error("the server did not answer")
            Sleep(50)
        }
        if (req.Status != 200) {
            if manual
                MsgBox("Could not check for updates (server returned HTTP " req.Status ").", "TouchDock Update", "Icon!")
            return
        }
        json := req.ResponseText
        newTag := "", releaseUrl := "", setupUrl := "", zipUrl := "", shaUrl := ""
        if RegExMatch(json, '"tag_name":\s*"([^"]+)"', &mTag)
            newTag := mTag[1]
        if RegExMatch(json, '"html_url":\s*"([^"]+)"', &mUrl)
            releaseUrl := mUrl[1]
        if RegExMatch(json, '"browser_download_url":\s*"([^"]+-setup\.exe)"', &mSetup)
            setupUrl := mSetup[1]
        if RegExMatch(json, '"browser_download_url":\s*"([^"]+-portable\.zip)"', &mZip)
            zipUrl := mZip[1]
        if RegExMatch(json, '"browser_download_url":\s*"([^"]+-setup\.exe\.sha256)"', &mSha)
            shaUrl := mSha[1]
        host := "https://github.com/fnx-tech/TouchDock/"
        ; Nothing is downloaded and run from anywhere but this project's releases.
        if (SubStr(setupUrl, 1, StrLen(host)) != host)
            setupUrl := ""
        if (SubStr(shaUrl, 1, StrLen(host)) != host)
            shaUrl := ""
        
        cleanTag := LTrim(newTag, "vV ")
        if (cleanTag != "" && IsNewerVersion(cleanTag, AppVersion)) {
            ShowUpdatePrompt(newTag, releaseUrl, setupUrl, zipUrl, shaUrl, manual)
        } else if manual {
            MsgBox("TouchDock is up to date (version " AppVersion ").", "TouchDock Update", "Iconi")
        }
    } catch as err {
        if manual
            MsgBox("Could not check for updates: " err.Message, "TouchDock Update", "Icon!")
    } finally
        busy := false
}

IsNewerVersion(remote, cur) {
    p1 := StrSplit(LTrim(remote, "vV "), ".")
    p2 := StrSplit(LTrim(cur, "vV "), ".")
    len := Max(p1.Length, p2.Length)
    loop len {
        n1 := (A_Index <= p1.Length && RegExMatch(p1[A_Index], "^\d+", &m1)) ? Integer(m1[0]) : 0  ; "2-rc1" counts as 2
        n2 := (A_Index <= p2.Length && RegExMatch(p2[A_Index], "^\d+", &m2)) ? Integer(m2[0]) : 0
        if (n1 > n2)
            return true
        if (n1 < n2)
            return false
    }
    return false
}

ShowUpdatePrompt(newVer, releaseUrl, setupUrl, zipUrl, shaUrl, manual := true) {
    g := Gui("+AlwaysOnTop -DPIScale", "TouchDock Update")
    g.BackColor := "202020"
    g.MarginX := 24, g.MarginY := 20
    g.SetFont("s11 cWhite", "Segoe UI")
    g.AddText("w360", "A new version of TouchDock is available!")
    g.SetFont("s10 cCCCCCC", "Segoe UI")
    g.AddText("w360 y+8", "Installed version:  v" AppVersion "`nLatest version:     " newVer)

    status := g.AddText("w360 y+12 Hidden c1C5FC4", "Downloading update...")
    b1 := g.AddButton("w110 h34 y+16" (manual ? " Default" : ""), "Update Now")
    b2 := g.AddButton("w110 h34 x+10", "Release Notes")
    b3 := g.AddButton("w110 h34 x+10", "Later")

    b3.OnEvent("Click", (*) => g.Destroy())
    b2.OnEvent("Click", (*) => (Run(releaseUrl), g.Destroy()))
    b1.OnEvent("Click", (*) => OnUpdateClicked(g, status, b1, b2, b3, newVer, releaseUrl, setupUrl, zipUrl, shaUrl))
    ; The automatic check must not take the focus (or an Enter keystroke) from the app being typed in.
    g.Show(manual ? "" : "NoActivate")
}

OnUpdateClicked(g, status, b1, b2, b3, newVer, releaseUrl, setupUrl, zipUrl, shaUrl) {
    isPortable := FileExist(A_ScriptDir "\portable")
    if (!A_IsCompiled || isPortable || setupUrl = "") {
        if (zipUrl != "")
            Run(zipUrl)
        else
            Run(releaseUrl)
        g.Destroy()
        return
    }
    b1.Enabled := false, b2.Enabled := false, b3.Enabled := false
    status.Visible := true
    status.Text := "Downloading installer..."
    SetTimer(() => RunDownload(g, status, b1, b2, b3, newVer, setupUrl, shaUrl), -50)
}

; expected: the text of a .sha256 file, "<64 hex digits>  <file name>".
ChecksumMatches(file, expected) {
    if !RegExMatch(expected, "i)^\s*([0-9a-f]{64})\b", &m)
        return false
    actual := FileSha256(file)
    return actual != "" && actual = StrLower(m[1])
}

; Windows' own certutil; "" when it fails.
FileSha256(file) {
    out := A_Temp "\TouchDock-hash.txt"
    try FileDelete(out)
    try RunWait(A_ComSpec ' /c ""certutil" -hashfile "' file '" SHA256 >"' out '" 2>&1"', , "Hide")
    catch
        return ""
    try text := FileRead(out)
    catch
        return ""
    try FileDelete(out)
    for line in StrSplit(text, "`n", "`r") {
        line := StrReplace(line, " ")
        if RegExMatch(line, "i)^[0-9a-f]{64}$")
            return StrLower(line)
    }
    return ""
}

RunDownload(g, status, b1, b2, b3, newVer, setupUrl, shaUrl) {
    tempExe := A_Temp "\TouchDock-" RegExReplace(newVer, "[^0-9A-Za-z.\-]", "_") "-setup.exe"
    try {
        if FileExist(tempExe)
            FileDelete(tempExe)
        if (shaUrl = "")
            throw Error("this release has no checksum file")
        shaFile := tempExe ".sha256"
        Download(shaUrl, shaFile)
        expected := FileRead(shaFile)
        FileDelete(shaFile)
        Download(setupUrl, tempExe)
    } catch as err {
        status.Text := "The installer was not downloaded: " err.Message ". Use Release Notes to get it by hand."
        b1.Enabled := b2.Enabled := b3.Enabled := true
        b3.Text := "Close"
        return
    }
    if !ChecksumMatches(tempExe, expected) {
        try FileDelete(tempExe)
        status.Text := "The downloaded installer does not match its checksum, so it was not run. Try again later or use Release Notes."
        b1.Enabled := b2.Enabled := b3.Enabled := true
        b3.Text := "Close"
        return
    }
    status.Text := "Starting installer..."
    Sleep(500)
    try Run('"' tempExe '"')
    catch as err {  ; the Windows permission prompt was declined, or the file is blocked
        status.Text := "The installer did not start: " err.Message
        b1.Enabled := b2.Enabled := b3.Enabled := true
        b3.Text := "Close"
        return
    }
    ExitApp()
}
