# Contributing to TouchDock

Thank you for helping. Bug reports, shared layouts, fixes and new features are all welcome.

## Reporting a bug

Open an issue with:

1. what you did, what you expected, and what happened instead;
2. Windows version, AutoHotkey version, and whether you were connected over Remote Desktop (and from which
   device and app).

## Sharing a layout

Paste the layout's section of `layouts.txt` (from its `[Name]` line down) in an issue or a pull request.

## Changing the code

1. TouchDock is AutoHotkey v2. Keep each file to its job: `layouts.ahk` reads and writes the layouts file
   (no windows), `grid.ahk` draws and presses, `editor.ahk` is the editor, `touchpad.ahk` the touchpad,
   `touchdock.ahk` the mic, menu and settings.
2. Every window TouchDock shows uses "no activate", so tapping it never moves the focus away from the app
   being typed in. New windows need the same.
3. Read the mouse with `GetKeyState("LButton")`, never with the "P" option: over Remote Desktop, presses do
   not count as physical while TouchDock's mouse hook is on.
4. Comments say why, not what: a limit from Windows or Remote Desktop, or what breaks if a line changes.

## Building the release files

`build/build.sh` (from WSL, on the Windows PC) compiles `dist\TouchDock.exe` with Ahk2Exe and writes
`dist\TouchDock-v<version>-portable.zip` and `dist\TouchDock-v<version>-setup.exe`. It needs AutoHotkey v2 with
Ahk2Exe and Inno Setup 6. The installer is `installer\touchdock.iss`; the version is set there. The exe carries
`layouts.txt` and `click.wav` (FileInstall) and writes them to its data folder when missing.

## Tests

The scripts in `tests\` run from WSL (bash) on the Windows PC where TouchDock runs:

1. `tests/editor-test.sh`: drives the layout editor on a fixed sample layout (no mouse needed).
2. `tests/run.sh layout-test.ahk <file>` and `tests/run.sh save-test.ahk <copy of a file>`: load and save
   checks for the layouts file.
3. `tests/run.sh pad-test.ahk`, `tests/run.sh tile-touch-test.ahk` and `tests/run.sh sticky-test.ahk`: simulated touches on the running
   TouchDock (the remote session must be connected; do not touch the dock while they run).

Run the tests that cover your change before opening a pull request, and say in the pull request which ones
you ran.
