# Virtual Desktop Manager for Windows

![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0+-green.svg)
![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-lightgrey.svg)

A powerful, lightweight AutoHotkey v2 script that enhances Windows virtual desktop management with intuitive keyboard shortcuts, persistent desktop naming, and seamless window management.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Instant Desktop Switching** | `Win+1` through `Win+9` to jump directly to desktops 1-9 |
| **Window Management** | `Win+Shift+1..9` moves active window to desktop N *and* follows it |
| **Desktop Cycling** | `Win+Ctrl+Left/Right` cycles through desktops |
| **Persistent Names** | Desktop names saved automatically to `%APPDATA%` |
| **Quick Actions** | `Win+W` close window • `Win+Shift+C` Firefox • `Win+Enter` Terminal |
| **Zero Dependencies** | Single DLL (`VirtualDesktopAccessor.dll`) for native Windows API access |
| **Crash-Safe** | Atomic config writes, automatic DLL cleanup on exit |

---

## 🚀 Quick Start

### Prerequisites
- Windows 10/11 (virtual desktop support required)
- [AutoHotkey v2.0+](https://www.autohotkey.com/download/ahk-v2.exe)

### Installation

1. **Clone the repository:**
   ```powershell
   git clone git@github.com:SuphalBhattarai/windows_shortcuts.git
   cd windows_shortcuts
   ```

2. **Install the DLL:**
   ```powershell
   # Create the required directory
   New-Item -ItemType Directory -Force -Path "$env:APPDATA\VirtualDesktopAccessor"
   
   # Copy the DLL (from lib/ folder)
   Copy-Item "lib\VirtualDesktopAccessor.dll" "$env:APPDATA\VirtualDesktopAccessor\"
   ```

3. **Run the script:**
   - Double-click `src\virtual_desktops.ahk`
   - Or compile to EXE: `Ahk2Exe.exe /in src\virtual_desktops.ahk /out VirtualDesktopManager.exe`

4. **Auto-start (optional):**
   - Create shortcut in `shell:startup` → `VirtualDesktopManager.exe`

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Win` + `1` – `9` | Switch to desktop 1–9 |
| `Win` + `Shift` + `1` – `9` | Move active window to desktop 1–9 & follow |
| `Win` + `Ctrl` + `Left/Right` | Cycle desktops left/right |
| `Win` + `W` | Close active window |
| `Win` + `Shift` + `C` | Launch Firefox |
| `Win` + `Enter` | Launch Windows Terminal (`wt.exe`) |

> **Tip:** Desktop names persist across reboots. Rename via Windows' built-in desktop UI (Win+Tab → right-click desktop → Rename).

---

## 📁 Project Structure

```
windows_shortcuts/
├── .git/
├── .gitignore
├── LICENSE                      # GPL-3.0 license
├── README.md                    # This file
├── src/
│   ├── VDA.ahk                  # DLL wrapper class (core)
│   └── virtual_desktops.ahk     # Main script (hotkeys & logic)
├── lib/
│   └── VirtualDesktopAccessor.dll    # Native bridge (x64)
└── docs/                        # (placeholder for future docs)
```

---

## ⚙️ Configuration

All user data lives in `%APPDATA%\VirtualDesktopManager\`:

| File | Purpose |
|------|---------|
| `desktops.json` | Desktop names (auto-saved on exit) |

**Example `desktops.json`:**
```json
{
  "0": "Development",
  "1": "Browser",
  "2": "Communication",
  "3": "Media",
  "4": "Research",
  "5": "Testing",
  "6": "Admin",
  "7": "Gaming",
  "8": "Misc"
}
```

---

## 🔧 Technical Details

### Architecture
```
src/virtual_desktops.ahk (Main Entry)
    │
    ├── Hotkey registration & dispatch
    ├── Config load/save (atomic JSON)
    └── VDA class (static) [src/VDA.ahk]
         │
         ├── LoadLibrary → lib/VirtualDesktopAccessor.dll
         ├── GetProcAddress for 9 exports
         ├── RegisterWindowMessage (collision-safe)
         ├── DllCall → Windows VirtualDesktop API
         └── OnExit → FreeLibrary + hook cleanup
```

### DLL Exports Used
| Function | Purpose |
|----------|---------|
| `GetDesktopCount` | Total desktop count |
| `GetCurrentDesktopNumber` | Active desktop (0-based) |
| `GoToDesktopNumber` | Switch desktop |
| `CreateDesktop` | Create new desktop |
| `SetDesktopName` / `GetDesktopName` | Persistent naming |
| `MoveWindowToDesktopNumber` | Move HWND to desktop |
| `RegisterPostMessageHook` / `UnregisterPostMessageHook` | Desktop change notifications |

### Safety Features
- **Input validation** on all VDA methods (index bounds, HWND validity, type checks)
- **Exception-based errors** with user-facing TrayTip notifications
- **Atomic config writes** via temp file + `FileMove` (no corruption on crash)
- **Unique message ID** via `RegisterWindowMessage` (no cross-app conflicts)
- **Automatic cleanup** via `OnExit` (DLL unload, hook unregister)

---

## 🛠️ Building from Source

### Compile to Standalone EXE
```powershell
# Install Ahk2Exe (comes with AutoHotkey)
# Then:
Ahk2Exe.exe /in src\virtual_desktops.ahk /out VirtualDesktopManager.exe /icon custom.ico
```

### DLL Requirements
- `VirtualDesktopAccessor.dll` must be x64
- Place at `%APPDATA%\VirtualDesktopAccessor\VirtualDesktopAccessor.dll`
- Source: [VirtualDesktopAccessor](https://github.com/Ciantic/VirtualDesktopAccessor) (or build from source)

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| `TrayTip: Failed to load DLL` | Verify DLL exists at `%APPDATA%\VirtualDesktopAccessor\VirtualDesktopAccessor.dll` |
| Hotkeys don't work | Run as Administrator (some apps block hooks) |
| Desktop names reset | Check `%APPDATA%\VirtualDesktopManager\desktops.json` permissions |
| `Win+Shift+C` opens wrong browser | Edit `src\virtual_desktops.ahk` line 30: `Run "firefox"` → your browser path |

---

## 🤝 Contributing

1. Fork the repo
2. Create feature branch: `git checkout -b feat/amazing-feature`
3. Commit changes: `git commit -m 'feat: add amazing feature'`
4. Push: `git push origin feat/amazing-feature`
5. Open Pull Request

**Coding standards:**
- AutoHotkey v2.0 syntax
- Conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`)
- All VDA methods must validate inputs & throw exceptions
- Atomic file writes for any persistent data

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for details.

```
Virtual Desktop Manager - Windows virtual desktop enhancement
Copyright (C) 2024 Suphal Bhattarai

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

---

## 🙏 Acknowledgments

- [VirtualDesktopAccessor](https://github.com/Ciantic/VirtualDesktopAccessor) — Native DLL bridge
- [AutoHotkey v2](https://www.autohotkey.com/) — Scripting platform
- Windows VirtualDesktop API — Undocumented but powerful

---

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/SuphalBhattarai/windows_shortcuts/issues)
- **Discussions:** [GitHub Discussions](https://github.com/SuphalBhattarai/windows_shortcuts/discussions)

---

<div align="center">

**Made with ❤️ for Windows power users**

[⭐ Star this repo](https://github.com/SuphalBhattarai/windows_shortcuts) if you find it useful!

</div>