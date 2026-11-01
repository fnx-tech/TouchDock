; Automatic and manual update checking against GitHub releases.
; Included by touchdock.ahk, which owns the globals.

CheckUpdatesQuiet() {
    if !FileExist(IniFile)
        return
    last := IniRead(IniFile, "update", "lastcheck", "")
    if (last != "" && DateDiff(A_Now, last, "Hours") < 24)
        return
    CheckForUpdates(false)
}

CheckUpdatesManual(*) {
    CheckForUpdates(true)
}

CheckForUpdates(manual := false) {
    IniWrite(A_Now, IniFile, "update", "lastcheck")
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(4000, 4000, 6000, 6000)
        req.Open("GET", "https://api.github.com/repos/fnx-tech/TouchDock/releases/latest", false)
        req.SetRequestHeader("User-Agent", "TouchDock")
        req.Send()
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
            ShowUpdatePrompt(newTag, releaseUrl, setupUrl, zipUrl)
        } else if manual {
            MsgBox("TouchDock is up to date (version " AppVersion ").", "TouchDock Update", "Iconi")
        }
    } catch as err {
        if manual
            MsgBox("Could not check for updates: " err.Message, "TouchDock Update", "Icon!")
    }
}

IsNewerVersion(remote, cur) {
    p1 := StrSplit(LTrim(remote, "vV "), ".")
    p2 := StrSplit(LTrim(cur, "vV "), ".")
    len := Max(p1.Length, p2.Length)
    loop len {
        n1 := (A_Index <= p1.Length && IsInteger(p1[A_Index])) ? Integer(p1[A_Index]) : 0
        n2 := (A_Index <= p2.Length && IsInteger(p2[A_Index])) ? Integer(p2[A_Index]) : 0
        if (n1 > n2)
            return true
        if (n1 < n2)
            return false
    }
    return false
}

ShowUpdatePrompt(newVer, releaseUrl, setupUrl, zipUrl) {
    g := Gui("+AlwaysOnTop -DPIScale", "TouchDock Update")
    g.BackColor := "202020"
    g.MarginX := 24, g.MarginY := 20
    g.SetFont("s11 cWhite", "Segoe UI")
    g.AddText("w360", "A new version of TouchDock is available!")
    g.SetFont("s10 cCCCCCC", "Segoe UI")
    g.AddText("w360 y+8", "Installed version:  v" AppVersion "`nLatest version:     " newVer)

    status := g.AddText("w360 y+12 Hidden c1C5FC4", "Downloading update...")
    b1 := g.AddButton("w110 h34 y+16 Default", "Update Now")
    b2 := g.AddButton("w110 h34 x+10", "Release Notes")
    b3 := g.AddButton("w110 h34 x+10", "Later")

    b3.OnEvent("Click", (*) => g.Destroy())
    b2.OnEvent("Click", (*) => (Run(releaseUrl), g.Destroy()))
    b1.OnEvent("Click", (*) => OnUpdateClicked(g, status, b1, b2, b3, newVer, releaseUrl, setupUrl, zipUrl))
    g.Show()
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
    SetTimer(() => RunDownload(g, status, b1, b3, newVer, setupUrl), -50)
}

RunDownload(g, status, b1, b3, newVer, setupUrl) {
    tempExe := A_Temp "\TouchDock-" newVer "-setup.exe"
    try {
        if FileExist(tempExe)
            FileDelete(tempExe)
        Download(setupUrl, tempExe)
        status.Text := "Starting installer..."
        Sleep(500)
        Run('"' tempExe '"')
        ExitApp()
    } catch as err {
        status.Text := "Download failed: " err.Message
        b1.Enabled := true
        b3.Enabled := true
        b3.Text := "Close"
    }
}
