# DeskHider

DeskHider is a tiny Windows tray utility that toggles desktop icons when you double-click empty desktop space.

- Double-click empty desktop space to hide the icons.
- Double-click again to restore them.
- Double-clicking an actual icon still opens the icon normally.
- Uses the double-click speed configured in Windows.
- Optional **Run at startup** tray-menu toggle.
- No installer, service, telemetry, updater, or background polling.

## Download

Download `DeskHider.exe` from this repository's **Releases** page and run it. Right-click the tray icon to enable startup or exit.

## Run from source

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Double-click `DeskHider.ahk`.

AutoHotkey v1 is not supported by the rewritten script.

## Build locally

Compile `DeskHider.ahk` with the official [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe) compiler and an AutoHotkey v2 64-bit base executable.

The repository's GitHub Actions workflow also compile-checks every push and pull request. Pushing a tag such as `v2.0.0` builds the portable executable, creates a SHA-256 checksum, and publishes both as a GitHub Release.

```powershell
git tag v2.0.0
git push origin v2.0.0
```

## What changed in v2

- Ported the app from AutoHotkey v1 to AutoHotkey v2.
- Removed the original developer's hardcoded local `#Include` path.
- Uses Explorer's native **Show desktop icons** command instead of only hiding the ListView window.
- Reads the real icon visibility state instead of maintaining a separate variable.
- Replaced the per-icon rectangle loop with a single ListView hit-test.
- Uses Windows' configured double-click timing and movement limits.
- Added an optional startup shortcut from the tray menu.
- Keeps compiled binaries in Releases rather than committing them to the source branch.

## Credits

DeskHider was originally created by [Ian Divinagracia](https://github.com/iandiv/DeskHider). Its desktop hit-testing logic was based on work shared by iPhilip on the [AutoHotkey forum](https://www.autohotkey.com/boards/viewtopic.php?t=79451).

This fork remains available under the MIT License.
