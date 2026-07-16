#Requires AutoHotkey v2.0
#SingleInstance Force

;@Ahk2Exe-SetName DeskHider
;@Ahk2Exe-SetDescription Toggle desktop icons by double-clicking empty desktop space
;@Ahk2Exe-SetVersion 2.0.0
;@Ahk2Exe-SetProductName DeskHider
;@Ahk2Exe-SetCompanyName iammortal7
;@Ahk2Exe-SetCopyright MIT License

DetectHiddenWindows true
A_IconTip := "DeskHider"

SetupTrayMenu()

#HotIf IsDesktopUnderMouse()
~LButton::HandleDesktopClick()
#HotIf

SetupTrayMenu() {
    tray := A_TrayMenu
    tray.Delete()
    tray.Add("Run at startup", ToggleStartup)

    if FileExist(GetStartupShortcut())
        tray.Check("Run at startup")

    tray.Add()
    tray.Add("Exit", (*) => ExitApp())
}

ToggleStartup(itemName, itemPos, menu) {
    shortcut := GetStartupShortcut()

    try {
        if FileExist(shortcut) {
            FileDelete shortcut
            menu.Uncheck(itemName)
            return
        }

        if A_IsCompiled {
            target := A_ScriptFullPath
            arguments := ""
            iconFile := A_ScriptFullPath
        } else {
            target := A_AhkPath
            arguments := Chr(34) A_ScriptFullPath Chr(34)
            iconFile := A_AhkPath
        }

        FileCreateShortcut(
            target,
            shortcut,
            A_ScriptDir,
            arguments,
            "Toggle desktop icons by double-clicking empty desktop space",
            iconFile
        )
        menu.Check(itemName)
    } catch Error as err {
        MsgBox(
            "DeskHider could not update its startup shortcut.`n`n" err.Message,
            "DeskHider",
            "Iconx"
        )
    }
}

GetStartupShortcut() {
    return A_Startup "\DeskHider.lnk"
}

HandleDesktopClick(*) {
    static lastClickTime := 0
    static lastX := 0
    static lastY := 0

    MouseGetPos &x, &y

    now := DllCall("GetTickCount64", "UInt64")
    doubleClickTime := DllCall("GetDoubleClickTime", "UInt")
    doubleClickWidth := Max(1, DllCall("GetSystemMetrics", "Int", 36, "Int"))
    doubleClickHeight := Max(1, DllCall("GetSystemMetrics", "Int", 37, "Int"))

    isDoubleClick := (
        lastClickTime > 0
        && now - lastClickTime <= doubleClickTime
        && Abs(x - lastX) <= Ceil(doubleClickWidth / 2)
        && Abs(y - lastY) <= Ceil(doubleClickHeight / 2)
    )

    if isDoubleClick {
        lastClickTime := 0

        ; When icons are hidden there is nothing to hit-test, so restore them
        ; immediately. When visible, ignore a double-click directly on an icon.
        if !DesktopIconsAreVisible() || !IsDesktopIconAt(x, y)
            ToggleDesktopIcons()

        return
    }

    lastClickTime := now
    lastX := x
    lastY := y
}

IsDesktopUnderMouse() {
    MouseGetPos , , &windowHwnd

    if !windowHwnd
        return false

    try windowClass := WinGetClass("ahk_id " windowHwnd)
    catch
        return false

    return windowClass = "WorkerW" || windowClass = "Progman"
}

DesktopIconsAreVisible() {
    listView := GetDesktopListView()
    return listView && DllCall("IsWindowVisible", "Ptr", listView, "Int")
}

ToggleDesktopIcons() {
    static WM_COMMAND := 0x0111
    static TOGGLE_DESKTOP_ICONS := 0x7402
    static SW_HIDE := 0
    static SW_SHOW := 5

    shellView := GetDesktopShellView()

    ; This invokes Explorer's own View > Show desktop icons command, keeping
    ; Explorer's internal state synchronized with what is visible on screen.
    if shellView && DllCall(
        "PostMessageW",
        "Ptr", shellView,
        "UInt", WM_COMMAND,
        "Ptr", TOGGLE_DESKTOP_ICONS,
        "Ptr", 0,
        "Int"
    )
        return true

    ; Fallback for unusual Explorer configurations.
    listView := GetDesktopListView()
    if !listView
        return false

    isVisible := DllCall("IsWindowVisible", "Ptr", listView, "Int")
    DllCall("ShowWindow", "Ptr", listView, "Int", isVisible ? SW_HIDE : SW_SHOW)
    return true
}

GetDesktopShellView() {
    progman := DllCall("FindWindowW", "Str", "Progman", "Ptr", 0, "Ptr")

    if progman {
        shellView := DllCall(
            "FindWindowExW",
            "Ptr", progman,
            "Ptr", 0,
            "Str", "SHELLDLL_DefView",
            "Ptr", 0,
            "Ptr"
        )

        if shellView
            return shellView
    }

    for worker in WinGetList("ahk_class WorkerW") {
        shellView := DllCall(
            "FindWindowExW",
            "Ptr", worker,
            "Ptr", 0,
            "Str", "SHELLDLL_DefView",
            "Ptr", 0,
            "Ptr"
        )

        if shellView
            return shellView
    }

    return 0
}

GetDesktopListView() {
    shellView := GetDesktopShellView()
    if !shellView
        return 0

    return DllCall(
        "FindWindowExW",
        "Ptr", shellView,
        "Ptr", 0,
        "Str", "SysListView32",
        "Ptr", 0,
        "Ptr"
    )
}

IsDesktopIconAt(screenX, screenY) {
    static LVM_HITTEST := 0x1012
    static PROCESS_VM_OPERATION := 0x0008
    static PROCESS_VM_READ := 0x0010
    static PROCESS_VM_WRITE := 0x0020
    static MEM_COMMIT := 0x1000
    static MEM_RESERVE := 0x2000
    static MEM_RELEASE := 0x8000
    static PAGE_READWRITE := 0x04

    listView := GetDesktopListView()

    if !listView || !DllCall("IsWindowVisible", "Ptr", listView, "Int")
        return false

    point := Buffer(8, 0)
    NumPut "Int", screenX, "Int", screenY, point

    if !DllCall("ScreenToClient", "Ptr", listView, "Ptr", point.Ptr, "Int")
        return true

    hitTestInfo := Buffer(24, 0)
    NumPut "Int", NumGet(point, 0, "Int"), hitTestInfo, 0
    NumPut "Int", NumGet(point, 4, "Int"), hitTestInfo, 4

    try processId := WinGetPID("ahk_id " listView)
    catch
        return true

    access := PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE
    process := DllCall(
        "OpenProcess",
        "UInt", access,
        "Int", false,
        "UInt", processId,
        "Ptr"
    )

    if !process
        return true

    remoteBuffer := 0

    try {
        remoteBuffer := DllCall(
            "VirtualAllocEx",
            "Ptr", process,
            "Ptr", 0,
            "UPtr", hitTestInfo.Size,
            "UInt", MEM_COMMIT | MEM_RESERVE,
            "UInt", PAGE_READWRITE,
            "Ptr"
        )

        if !remoteBuffer
            return true

        if !DllCall(
            "WriteProcessMemory",
            "Ptr", process,
            "Ptr", remoteBuffer,
            "Ptr", hitTestInfo.Ptr,
            "UPtr", hitTestInfo.Size,
            "Ptr", 0,
            "Int"
        )
            return true

        iconIndex := DllCall(
            "SendMessageW",
            "Ptr", listView,
            "UInt", LVM_HITTEST,
            "Ptr", 0,
            "Ptr", remoteBuffer,
            "Int"
        )

        return iconIndex >= 0
    } finally {
        if remoteBuffer
            DllCall(
                "VirtualFreeEx",
                "Ptr", process,
                "Ptr", remoteBuffer,
                "UPtr", 0,
                "UInt", MEM_RELEASE,
                "Int"
            )

        DllCall("CloseHandle", "Ptr", process)
    }
}
