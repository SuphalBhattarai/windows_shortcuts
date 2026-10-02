#Requires AutoHotkey v2.0

class VDA {
    static hModule := 0
    static initialized := false
    static DLL_PATH := A_AppData "\VirtualDesktopAccessor\VirtualDesktopAccessor.dll"
    static _msgDesktopChange := 0
    static _GetCount := 0
    static _GoTo := 0
    static _Current := 0
    static _Create := 0
    static _SetName := 0
    static _GetName := 0
    static _MoveWindow := 0
    static _RegisterHook := 0
    static _UnregisterHook := 0

    static __New() {
        throw "VDA is static-only"
    }

    static Init() {
        if this.initialized
            return true

        local dllPath := this.DLL_PATH
        if !FileExist(dllPath) {
            OutputDebug "VDA.dll not found at " dllPath
            return false
        }

        this.hModule := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
        if !this.hModule {
            local err := A_LastError
            OutputDebug "Failed to load VDA.dll (Error " err ")"
            return false
        }

        this._GetCount := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "GetDesktopCount", "Ptr")
        this._GoTo := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "GoToDesktopNumber", "Ptr")
        this._Current := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "GetCurrentDesktopNumber", "Ptr")
        this._Create := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "CreateDesktop", "Ptr")
        this._SetName := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "SetDesktopName", "Ptr")
        this._GetName := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "GetDesktopName", "Ptr")
        this._MoveWindow := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "MoveWindowToDesktopNumber", "Ptr")
        this._RegisterHook := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "RegisterPostMessageHook", "Ptr")
        this._UnregisterHook := DllCall("GetProcAddress", "Ptr", this.hModule, "Str", "UnregisterPostMessageHook", "Ptr")

        ; Register unique message
        this._msgDesktopChange := DllCall("RegisterWindowMessage", "Str", "VDA_DesktopChange", "UInt")
        
        if this._RegisterHook
            DllCall(this._RegisterHook, "Ptr", A_ScriptHwnd, "UInt", this._msgDesktopChange, "Int")

        OnMessage(this._msgDesktopChange, VDA.OnChangeDesktop)
        OnExit(VDA.Shutdown)
        this.initialized := true
        return true
    }

    static GetCount() {
        if !this.initialized
            throw Exception("VDA not initialized")
        return DllCall(this._GetCount, "Int")
    }

    static GetCurrent() {
        if !this.initialized
            throw Exception("VDA not initialized")
        return DllCall(this._Current, "Int")
    }

    static GoTo(n) {
        if !this.initialized
            throw Exception("VDA not initialized")
        if !IsInt(n) || n < 0
            throw Exception("Invalid desktop index: " n)
        return DllCall(this._GoTo, "Int", n, "Int") != -1
    }

    static Create() {
        if !this.initialized
            throw Exception("VDA not initialized")
        return DllCall(this._Create, "Int")
    }

    static Ensure(n) {
        if !this.initialized
            throw Exception("VDA not initialized")
        if !IsInt(n) || n < 0
            throw Exception("Invalid desktop index: " n)
        local count := this.GetCount()
        while count <= n {
            local newIdx := this.Create()
            if newIdx = -1
                throw Exception("Failed to create desktop")
            count := this.GetCount()
        }
        return true
    }

    static GetName(n) {
        if !this.initialized
            throw Exception("VDA not initialized")
        if !IsInt(n) || n < 0
            throw Exception("Invalid desktop index: " n)
        local buf := Buffer(1024, 0)
        local len := DllCall(this._GetName, "Int", n, "Ptr", buf, "Ptr", buf.Size, "Int")
        return StrGet(buf, "UTF-8")
    }

    static SetName(n, name) {
        if !this.initialized
            throw Exception("VDA not initialized")
        if !IsInt(n) || n < 0
            throw Exception("Invalid desktop index: " n)
        if !IsStr(name)
            throw Exception("Name must be string")
        local buf := Buffer(1024, 0)
        StrPut(name, buf, "UTF-8")
        return DllCall(this._SetName, "Int", n, "Ptr", buf, "Int") != -1
    }

    static MoveWindow(hwnd, n) {
        if !this.initialized
            throw Exception("VDA not initialized")
        if !IsInt(n) || n < 0
            throw Exception("Invalid desktop index: " n)
        if !DllCall("IsWindow", "Ptr", hwnd)
            throw Exception("Invalid window handle")
        DllCall(this._MoveWindow, "Ptr", hwnd, "Int", n, "Int")
        return true
    }

    static MoveCurrentWindowToDesktop(n) {
        return this.MoveWindow(WinGetID("A"), n)
    }

    static OnChangeDesktop(wParam, lParam, msg, hwnd) {
        local newDesktop := lParam + 1
        local name := this.GetName(newDesktop - 1)
        OutputDebug "Desktop changed to " name
    }

    static Shutdown() {
        if this.hModule {
            if this._UnregisterHook && this._msgDesktopChange
                DllCall(this._UnregisterHook, "Ptr", A_ScriptHwnd, "UInt", this._msgDesktopChange)
            DllCall("FreeLibrary", "Ptr", this.hModule)
            this.hModule := 0
        }
        this.initialized := false
    }
}