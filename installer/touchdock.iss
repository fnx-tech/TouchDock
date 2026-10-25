; Inno Setup 6 script. Build with build\build.sh; it needs dist\TouchDock.exe (compiled first).
#define AppVersion "1.0"

[Setup]
AppId={{6F1C2B7E-4D3A-4B8E-9A52-7C0E5D1A3F64}
AppName=TouchDock
AppVersion={#AppVersion}
AppPublisher=fnx-tech
AppPublisherURL=https://github.com/fnx-tech/TouchDock
DefaultDirName={autopf}\TouchDock
DefaultGroupName=TouchDock
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename=TouchDock-v{#AppVersion}-setup
UninstallDisplayIcon={app}\TouchDock.exe
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
; Admin by default (Program Files); /CURRENTUSER on the command line installs without a UAC prompt.
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; Flags: unchecked
Name: "startup"; Description: "&Start TouchDock with Windows"; Flags: unchecked

[Files]
Source: "..\dist\TouchDock.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\TouchDock"; Filename: "{app}\TouchDock.exe"
Name: "{autodesktop}\TouchDock"; Filename: "{app}\TouchDock.exe"; Tasks: desktopicon
; All users in an admin install: {userstartup} would be the elevating account's, which may not be the person using it.
Name: "{autostartup}\TouchDock"; Filename: "{app}\TouchDock.exe"; Tasks: startup

[Run]
Filename: "{app}\TouchDock.exe"; Description: "Run TouchDock"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usDone) and not UninstallSilent then
    MsgBox('TouchDock was removed. Your layouts and settings were kept in ' +
      ExpandConstant('{userappdata}\TouchDock') + '. Delete that folder if you do not want them.',
      mbInformation, MB_OK);
end;
