<# 
.SYNOPSIS
    Install Virtual Desktop Manager - Windows virtual desktop enhancement

.DESCRIPTION
    Installs the Virtual Desktop Manager by copying the native DLL to %APPDATA%\shortcuts\,
    optionally compiling to EXE, and creating a startup shortcut.

.PARAMETER NoAutoStart
    Skip creating startup shortcut (default: create shortcut)

.PARAMETER Compile
    Force compilation to EXE (requires AutoHotkey v2 with Ahk2Exe)

.PARAMETER Uninstall
    Remove installation (preserves desktops.json config)

.PARAMETER NoPrompt
    Silent mode - no interactive prompts (implies -Compile:$false)

.PARAMETER Force
    Overwrite existing files without confirmation

.EXAMPLE
    .\install.ps1
    # Installs DLL, creates startup shortcut, no compilation

.EXAMPLE
    .\install.ps1 -NoAutoStart
    # Installs DLL only, no startup shortcut

.EXAMPLE
    .\install.ps1 -Compile
    # Installs DLL, compiles to EXE if Ahk2Exe found, creates shortcut

.EXAMPLE
    .\install.ps1 -Uninstall
    # Removes DLL, EXE, and startup shortcut (keeps config)
#>

param(
    [switch]$NoAutoStart,
    [switch]$Compile,
    [switch]$Uninstall,
    [switch]$NoPrompt,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Constants ───
$SCRIPT_DIR = $PSScriptRoot
$SOURCE_DLL = Join-Path $SCRIPT_DIR 'lib\VirtualDesktopAccessor.dll'
$SOURCE_AHK = Join-Path $SCRIPT_DIR 'src\virtual_desktops.ahk'

$BASE_DIR = Join-Path $env:APPDATA 'shortcuts'
$TARGET_DLL = Join-Path $BASE_DIR 'VirtualDesktopAccessor.dll'
$TARGET_EXE = Join-Path $BASE_DIR 'VirtualDesktopManager.exe'
$CONFIG_FILE = Join-Path $BASE_DIR 'desktops.json'
$HASH_FILE = Join-Path $BASE_DIR '.dllhash'

# Install log stored in script directory (repo root)
$LOG_FILE = Join-Path $SCRIPT_DIR 'install.log'

$STARTUP_DIR = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$STARTUP_SHORTCUT = Join-Path $STARTUP_DIR 'Virtual Desktop Manager.lnk'

$EXPECTED_HASH = 'f78ff6334f6c0ef5175ec0819026cec31d421a564b9ed1ee1ac4b6ed98d4f999'

# ─── Logging Functions ───
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = switch ($Level) {
        'WARN'  { '[WARN] ' }
        'ERROR' { '[ERROR] ' }
        default { '[INFO]  ' }
    }
    $logLine = "$timestamp $prefix$Message"
    
    # Write to console
    Write-Host $logLine
    
    # Write to log file
    try {
        Ensure-Directory $BASE_DIR
        Add-Content -Path $LOG_FILE -Value $logLine -Encoding UTF8 -ErrorAction Stop
    } catch {
        # If log file write fails, continue silently (don't break install)
    }
}

function Write-ErrorExit {
    param([string]$Message)
    Write-Log $Message 'ERROR'
    # Pause before exit so user can read error
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

function Pause-AndExit {
    param([int]$ExitCode = 0)
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "Installation complete. Log saved to:"
    Write-Host "  $LOG_FILE"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Press any key to close this window..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit $ExitCode
}

# ─── Core Functions ───
function Test-RepoRoot {
    if (-not (Test-Path $SOURCE_DLL)) {
        Write-ErrorExit "Not in repository root. Expected lib\VirtualDesktopAccessor.dll at $SOURCE_DLL"
    }
    if (-not (Test-Path $SOURCE_AHK)) {
        Write-ErrorExit "Not in repository root. Expected src\virtual_desktops.ahk at $SOURCE_AHK"
    }
    Write-Log "Repository root verified: $SCRIPT_DIR"
}

function Get-DLLHash {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
    } catch {
        Write-Log "Failed to compute hash for $Path : $($_.Exception.Message)" 'WARN'
        return $null
    }
}

function Find-Ahk2Exe {
    $candidates = @(
        "${env:ProgramFiles}\AutoHotkey\Compiler\Ahk2Exe.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\Compiler\Ahk2Exe.exe",
        (Get-Command Ahk2Exe.exe -ErrorAction SilentlyContinue).Source
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) {
            try {
                $ver = & $c /? 2>&1
                if ($ver -match 'v2\.\d') {
                    Write-Log "Found Ahk2Exe (AHK v2): $c"
                    return $c
                }
            } catch { }
        }
    }
    return $null
}

function Test-Admin {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Log "Created directory: $Path"
        } catch {
            Write-ErrorExit "Failed to create directory $Path : $($_.Exception.Message)"
        }
    }
}

function Copy-DLL {
    Write-Log "Copying DLL to $TARGET_DLL"
    try {
        Ensure-Directory $BASE_DIR
        Copy-Item -Path $SOURCE_DLL -Destination $TARGET_DLL -Force
    } catch {
        Write-ErrorExit "DLL copy failed: $($_.Exception.Message)`nSource: $SOURCE_DLL`nTarget: $TARGET_DLL"
    }
    
    # Verify copied DLL
    $copiedHash = Get-DLLHash $TARGET_DLL
    if ($copiedHash -ne $EXPECTED_HASH) {
        Write-ErrorExit "DLL hash verification FAILED after copy!`nExpected: $EXPECTED_HASH`nGot:      $copiedHash"
    }
    Write-Log "DLL copied and verified (SHA256: $copiedHash)"
    
    # Store hash for future comparisons
    Set-Content -Path $HASH_FILE -Value $copiedHash -Encoding UTF8
}

function Verify-InstalledDLL {
    if (-not (Test-Path $TARGET_DLL)) {
        Write-Log "DLL not installed at $TARGET_DLL" 'WARN'
        return $false
    }
    $installedHash = Get-DLLHash $TARGET_DLL
    $storedHash = $null
    if (Test-Path $HASH_FILE) {
        $storedHash = (Get-Content $HASH_FILE -Raw).Trim().ToLower()
    }
    
    if ($installedHash -eq $EXPECTED_HASH -and $installedHash -eq $storedHash) {
        Write-Log "DLL verified (hash matches)"
        return $true
    }
    Write-Log "DLL hash mismatch (installed: $installedHash, expected: $EXPECTED_HASH, stored: $storedHash)" 'WARN'
    return $false
}

function Compile-Script {
    param([string]$Ahk2ExePath)
    
    Write-Log "Compiling with Ahk2Exe: $Ahk2ExePath"
    try {
        $result = & $Ahk2ExePath /in $SOURCE_AHK /out $TARGET_EXE 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Compilation failed (exit $LASTEXITCODE): $result" 'WARN'
            return $false
        }
        if (-not (Test-Path $TARGET_EXE)) {
            Write-Log "Compilation reported success but EXE not found" 'WARN'
            return $false
        }
        Write-Log "Compiled successfully: $TARGET_EXE"
        return $true
    } catch {
        Write-Log "Compilation error: $($_.Exception.Message)" 'WARN'
        return $false
    }
}

function Create-StartupShortcut {
    param([string]$TargetPath)
    
    Write-Log "Creating startup shortcut: $STARTUP_SHORTCUT"
    try {
        Ensure-Directory $STARTUP_DIR
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($STARTUP_SHORTCUT)
        $shortcut.TargetPath = $TargetPath
        $shortcut.WorkingDirectory = $BASE_DIR
        $shortcut.Description = "Virtual Desktop Manager - AutoHotkey v2"
        $shortcut.Save()
        Write-Log "Startup shortcut created"
        return $true
    } catch {
        Write-Log "Failed to create startup shortcut: $($_.Exception.Message)" 'WARN'
        return $false
    }
}

function Remove-StartupShortcut {
    if (Test-Path $STARTUP_SHORTCUT) {
        try {
            Remove-Item $STARTUP_SHORTCUT -Force -ErrorAction Stop
            Write-Log "Removed startup shortcut"
        } catch {
            Write-Log "Failed to remove startup shortcut: $($_.Exception.Message)" 'WARN'
        }
    }
}

function Uninstall-All {
    Write-Log "=== UNINSTALL ==="
    Remove-StartupShortcut
    
    if (Test-Path $TARGET_DLL) {
        try { Remove-Item $TARGET_DLL -Force; Write-Log "Removed DLL" }
        catch { Write-Log "Failed to remove DLL: $($_.Exception.Message)" 'WARN' }
    }
    if (Test-Path $TARGET_EXE) {
        try { Remove-Item $TARGET_EXE -Force; Write-Log "Removed EXE" }
        catch { Write-Log "Failed to remove EXE: $($_.Exception.Message)" 'WARN' }
    }
    if (Test-Path $HASH_FILE) {
        try { Remove-Item $HASH_FILE -Force; Write-Log "Removed hash file" }
        catch { Write-Log "Failed to remove hash file: $($_.Exception.Message)" 'WARN' }
    }
    if (Test-Path $LOG_FILE) {
        try { Remove-Item $LOG_FILE -Force; Write-Log "Removed log file" }
        catch { Write-Log "Failed to remove log file: $($_.Exception.Message)" 'WARN' }
    }
    
    # Preserve config
    if (Test-Path $CONFIG_FILE) {
        Write-Log "Config preserved: $CONFIG_FILE"
    }
    
    Write-Log "Uninstall complete"
}

function Install-Main {
    Write-Log "=== INSTALL Virtual Desktop Manager ==="
    Write-Log "Base directory: $BASE_DIR"
    Write-Log "Log file: $LOG_FILE"
    
    # 1. Verify/Install DLL
    if (-not (Verify-InstalledDLL)) {
        Write-Log "Installing/updating DLL..."
        Copy-DLL
    }
    
    # 2. Determine launch target (EXE or AHK)
    $launchTarget = $SOURCE_AHK
    $ahk2exe = Find-Ahk2Exe
    
    $shouldCompile = $false
    if ($Compile) {
        $shouldCompile = $true
        Write-Log "Compile forced via -Compile"
    } elseif ($ahk2exe -and -not $NoPrompt) {
        Write-Host ""
        $choice = Read-Host "Ahk2Exe found (AHK v2). Compile to EXE? (Y/n)"
        $shouldCompile = $choice -notmatch '^n'
    } elseif ($ahk2exe -and $NoPrompt) {
        Write-Log "Ahk2Exe found but -NoPrompt specified, skipping compile"
    } else {
        Write-Log "Ahk2Exe not found (AHK v2 not installed or not in PATH), skipping compile"
    }
    
    if ($shouldCompile -and $ahk2exe) {
        if (Compile-Script $ahk2exe) {
            $launchTarget = $TARGET_EXE
        } else {
            Write-Log "Compilation failed, falling back to .ahk script" 'WARN'
        }
    }
    
    # 3. Startup shortcut
    if (-not $NoAutoStart) {
        Create-StartupShortcut $launchTarget
    } else {
        Write-Log "Skipping startup shortcut (-NoAutoStart)"
    }
    
    # 4. Summary
    Write-Host ""
    Write-Log "=== INSTALL COMPLETE ==="
    Write-Log "DLL:       $TARGET_DLL"
    Write-Log "Config:    $CONFIG_FILE (preserved on update/uninstall)"
    if (Test-Path $TARGET_EXE) { Write-Log "EXE:       $TARGET_EXE" }
    Write-Log "Launch:    $launchTarget"
    if (-not $NoAutoStart) { Write-Log "Startup:   Enabled" } else { Write-Log "Startup:   Disabled" }
    Write-Host ""
    Write-Log "Run manually: $launchTarget"
    Write-Log "Uninstall:    .\install.ps1 -Uninstall"
}

# ─── Main Entry ───
try {
    # Initialize log file (clear previous)
    Ensure-Directory $BASE_DIR
    if (Test-Path $LOG_FILE) {
        Clear-Content $LOG_FILE -ErrorAction SilentlyContinue
    }
    
    Write-Log "Starting Virtual Desktop Manager installer"
    Write-Log "Script directory: $SCRIPT_DIR"
    Write-Log "Parameters: NoAutoStart=$NoAutoStart, Compile=$Compile, Uninstall=$Uninstall, NoPrompt=$NoPrompt, Force=$Force"
    
    Test-RepoRoot
    
    if ($Uninstall) {
        Uninstall-All
        Pause-AndExit 0
    }
    
    # Elevate only if needed (for startup shortcut creation in some environments)
    # AppData doesn't require admin, but startup folder might in locked-down environments
    if (-not $NoAutoStart -and -not (Test-Admin)) {
        Write-Log "Running without admin privileges (AppData install doesn't require elevation)"
    }
    
    Install-Main
    Pause-AndExit 0
}
catch {
    Write-ErrorExit "Fatal error: $($_.Exception.Message)"
}