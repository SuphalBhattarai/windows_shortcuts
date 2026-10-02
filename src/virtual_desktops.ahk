#Requires AutoHotkey v2.0
#SingleInstance Force

#include VDA.ahk

SCRIPT_DIR := A_ScriptDir
CONFIG_DIR := A_AppData "\shortcuts"
CONFIG_FILE := CONFIG_DIR "\desktops.json"
VDA_DLL_PATH := A_AppData "\shortcuts\VirtualDesktopAccessor.dll"

; --- Init VDA ---
vdaOk := VDA.Init()
if !vdaOk {
    TrayTip "Virtual Desktops", "Failed to load VirtualDesktopAccessor.dll`nExpected at: " VDA_DLL_PATH, 5, 0x2
    Sleep 3000
    ExitApp
}

; Ensure config dir exists
if !DirExist(CONFIG_DIR)
    DirCreate CONFIG_DIR

; --- Load persisted desktop names ---
desktopNames := {}
if FileExist(CONFIG_FILE) {
    try
        desktopNames := JsonParse(FileRead(CONFIG_FILE))
}
for n, name in desktopNames {
    VDA.SetName(Integer(n), name)
}

; --- Save names on exit ---
OnExit(*) => SaveConfig()

; --- Win+1..9 : Switch to desktop N ---
Loop 9 {
    i := A_Index
    if !Hotkey "#" i, (*) => GoToDesktop(i - 1)
        OutputDebug "Failed to register Win+" i
}

; --- Win+Shift+1..9 : Move active window to desktop N ---
Loop 9 {
    i := A_Index
    if !Hotkey "#+" i, (*) => MoveWindowToDesktop(i - 1)
        OutputDebug "Failed to register Win+Shift+" i
}

; --- From shortcut.txt ---
Hotkey "#w", (*) => WinClose("A")
Hotkey "#+c", (*) => Run "firefox"
Hotkey "#Enter", (*) => Run "wt.exe"

; --- Win+Ctrl+Left/Right : Cycle desktops ---
Hotkey "#^Left", (*) => CycleDesktop(-1)
Hotkey "#^Right", (*) => CycleDesktop(1)

; --- Functions ---
GoToDesktop(n) {
    try {
        VDA.Ensure(n)
        VDA.GoTo(n)
    } catch e {
        TrayTip "Virtual Desktops", "GoToDesktop failed: " e.Message, 3, 0x2
    }
}

MoveWindowToDesktop(n) {
    try {
        VDA.Ensure(n)
        VDA.MoveCurrentWindowToDesktop(n)
        VDA.GoTo(n)
    } catch e {
        TrayTip "Virtual Desktops", "MoveWindowToDesktop failed: " e.Message, 3, 0x2
    }
}

CycleDesktop(dir) {
    local count := VDA.GetCount()
    if count = 0
        return
    local current := VDA.GetCurrent()
    local target := Mod(current + dir, count)
    VDA.GoTo(target)
}

SaveConfig() {
    local names := {}
    local count := VDA.GetCount()
    Loop count {
        i := A_Index - 1
        names[i] := VDA.GetName(i)
    }
    try {
        local tmpFile := CONFIG_FILE ".tmp"
        FileDelete tmpFile
        FileAppend JsonStringify(names), tmpFile
        FileMove tmpFile, CONFIG_FILE, 1
    }
}