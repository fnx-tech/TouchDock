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
        newTag := "", releaseUrl := "", setupUrl := "", zipUrl := ""
        if RegExMatch(json, '"tag_name":\s*"([^"]+)"', &mTag)
            newTag := mTag[1]
        if RegExMatch(json, '"html_url":\s*"([^"]+)"', &mUrl)
            releaseUrl := mUrl[1]
        if RegExMatch(json, '"browser_download_url":\s*"([^"]+-setup\.exe)"', &mSetup)
            setupUrl := mSetup[1]
        if RegExMatch(json, '"browser_download_url":\s*"([^"]+-portable\.zip)"', &mZip)
            zipUrl := mZip[1]
        
        cleanTag := LTrim(newTag, "vV ")
        if (cleanTag != "" && IsNewerVersion(cleanTag, AppVersion)) {
            ShowUpdatePrompt(newTag, releaseUrl, setupUrl, zipUrl, manual)
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

ShowUpdatePrompt(newVer, releaseUrl, setupUrl, zipUrl, manual := true) {
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
    b1.OnEvent("Click", (*) => OnUpdateClicked(g, status, b1, b2, b3, newVer, releaseUrl, setupUrl, zipUrl))
    ; The automatic check must not take the focus (or an Enter keystroke) from the app being typed in.
    g.Show(manual ? "" : "NoActivate")
}

OnUpdateClicked(g, status, b1, b2, b3, newVer, releaseUrl, setupUrl, zipUrl) {
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
    SetTimer(() => RunDownload(g, status, b1, b2, b3, newVer, setupUrl), -50)
}

RunDownload(g, status, b1, b2, b3, newVer, setupUrl) {
    tempExe := A_Temp "\TouchDock-" RegExReplace(newVer, "[^0-9A-Za-z.\-]", "_") "-setup.exe"
    try {
        if FileExist(tempExe)
            FileDelete(tempExe)
        Download(setupUrl, tempExe)
    } catch as err {
        status.Text := "Download failed: " err.Message
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
