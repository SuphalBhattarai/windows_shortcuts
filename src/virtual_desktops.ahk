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
    TrayTip "Virtual Desktops", "Failed to load VirtualDesktopAccessor.dll`nExpected at: " VDA_DLL_PATH, 5
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

; --- LWin & 1..9 : Switch to desktop N (hold LWin, tap number) ---
Loop 9 {
    i := A_Index
    Hotkey "LWin & " i, (*) => GoToDesktop(i - 1)
}

; --- LWin & Shift+1..9 : Move active window to desktop N ---
Loop 9 {
    i := A_Index
    Hotkey "LWin & Shift+ " i, (*) => MoveWindowToDesktop(i - 1)
}

; --- Win+W : Close window (only when NOT on Widgets panel) ---
#HotIf !WinActive("ahk_class Windows.UI.Core.CoreWindow")
#w::WinClose("A")
#HotIf

; --- Win+Shift+C : Open Firefox ---
#+c::Run "firefox"

; --- Win+Enter : Open Windows Terminal ---
#Enter::Run "wt.exe"

; --- Win+Ctrl+Left/Right : Cycle desktops ---
#^Left::CycleDesktop(-1)
#^Right::CycleDesktop(1)

; --- Functions ---
GoToDesktop(n) {
    try {
        VDA.Ensure(n)
        VDA.GoTo(n)
    } catch as err {
        TrayTip "Virtual Desktops", "GoToDesktop failed: " err.Message, 3
    }
}

MoveWindowToDesktop(n) {
    try {
        VDA.Ensure(n)
        VDA.MoveCurrentWindowToDesktop(n)
        VDA.GoTo(n)
    } catch as err {
        TrayTip "Virtual Desktops", "MoveWindowToDesktop failed: " err.Message, 3
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