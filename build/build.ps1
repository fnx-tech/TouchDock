# build.ps1 : builds dist/TouchDock.exe, dist/TouchDock-v<version>-portable.zip and dist/TouchDock-v<version>-setup.exe.
# Run in PowerShell on Windows.
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root "dist"
$IssFile = Join-Path $Root "installer\touchdock.iss"

# Extract version from touchdock.iss
$VersionMatch = Select-String -Path $IssFile -Pattern '^#define AppVersion "(.*)"'
if (-not $VersionMatch) {
    throw "Could not find AppVersion in $IssFile"
}
$Version = $VersionMatch.Matches[0].Groups[1].Value
$AhkMatch = Select-String -Path (Join-Path $Root "touchdock.ahk") -Pattern '^AppVersion\s*:=\s*"([^"]*)"'
if (-not $AhkMatch -or $AhkMatch.Matches[0].Groups[1].Value -ne $Version) {
    throw "Version mismatch between touchdock.ahk and $IssFile"
}
Write-Host "Building TouchDock v$Version..." -ForegroundColor Cyan

# Locate compiler and tools
$Ahk2Exe = "$env:LOCALAPPDATA\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"
if (-not (Test-Path $Ahk2Exe)) {
    throw "Ahk2Exe not found at $Ahk2Exe"
}

$AhkBase = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path $AhkBase)) {
    throw "AutoHotkey64 base binary not found at $AhkBase"
}

$Iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $Iscc)) {
    $Iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
}
if (-not (Test-Path $Iscc)) {
    throw "Inno Setup compiler (ISCC.exe) not found"
}

# Ensure dist exists and remove previous build outputs
if (-not (Test-Path $Dist)) {
    New-Item -ItemType Directory -Path $Dist | Out-Null
}
Remove-Item -Path "$Dist\TouchDock.exe", "$Dist\TouchDock-v$Version-portable.zip", "$Dist\TouchDock-v$Version-setup.exe" -ErrorAction SilentlyContinue

# 1. Compile TouchDock.exe
Write-Host "Compiling TouchDock.exe..."
$SrcAhk = Join-Path $Root "touchdock.ahk"
$OutExe = Join-Path $Dist "TouchDock.exe"

$proc = Start-Process -FilePath $Ahk2Exe -ArgumentList "/in `"$SrcAhk`" /out `"$OutExe`" /base `"$AhkBase`"" -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0 -or -not (Test-Path $OutExe)) {
    throw "Ahk2Exe compilation failed with exit code $($proc.ExitCode)"
}

# 2. Package Portable Zip
Write-Host "Packaging portable zip..."
$TempPortable = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TempPortable | Out-Null
Copy-Item -Path $OutExe, (Join-Path $Root "LICENSE") -Destination $TempPortable
New-Item -ItemType File -Path (Join-Path $TempPortable "portable") | Out-Null

$PortableZip = Join-Path $Dist "TouchDock-v$Version-portable.zip"
if (Test-Path $PortableZip) { Remove-Item $PortableZip }
Compress-Archive -Path "$TempPortable\*" -DestinationPath $PortableZip -CompressionLevel Optimal
Remove-Item -Recurse -Force $TempPortable

# 3. Compile Installer with Inno Setup
Write-Host "Compiling installer with Inno Setup..."
$isccProc = Start-Process -FilePath $Iscc -ArgumentList "`"$IssFile`"" -NoNewWindow -Wait -PassThru
if ($isccProc.ExitCode -ne 0) {
    throw "Inno Setup compilation failed with exit code $($isccProc.ExitCode)"
}

# "<hash>  <file name>", which the updater checks the downloaded installer against; upload them with each release.
foreach ($name in "TouchDock-v$Version-setup.exe", "TouchDock-v$Version-portable.zip") {
    $hash = (Get-FileHash -Path (Join-Path $Dist $name) -Algorithm SHA256).Hash.ToLower()
    [System.IO.File]::WriteAllText((Join-Path $Dist "$name.sha256"), "$hash  $name`n", (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host "Build complete! Artifacts in dist:" -ForegroundColor Green
Get-ChildItem -Path $Dist | Select-Object Name, Length, LastWriteTime
