# procs.ps1 [kill] : lists AutoHotkey processes with their script; "kill" ends the mic button's one.
param([string]$action)
Get-CimInstance Win32_Process | Where-Object Name -eq 'AutoHotkey64.exe' | ForEach-Object {
  "$($_.ProcessId) $($_.CommandLine)"
  if ($action -eq 'kill' -and $_.CommandLine -like '*touchdock.ahk*') { Stop-Process -Id $_.ProcessId -Force; "  stopped" }
}
