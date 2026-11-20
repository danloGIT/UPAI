<#
.SYNOPSIS
    Universal Portable App Installer (UPAI) - Pro Edition v1.1.0 (PowerShell)

.DESCRIPTION
    Integrates a portable Windows application into the system by optionally
    moving its folder to the architecture-appropriate Program Files directory,
    creating a standalone uninstaller, registering the app under Windows
    Installed Apps (HKLM), and creating All-Users Desktop & Start Menu shortcuts.

    Copyright (c) 2026 danloGIT/Kardani
    Licensed under the GNU General Public License v3.0 or later.
#>

[CmdletBinding()]
param(
    # Positional argument: application display name (like %1 in Batch)
    [Parameter(Position = 0)]
    [string]$AppName,

    # Optional path to the main executable inside the app folder
    [string]$Exe,

    # Run non-interactively (requires -AppName, and -Exe if multiple .exe files exist)
    [switch]$Silent,

    # Automatically move the app folder to Program Files / Program Files (x86)
    [Alias('Move')]
    [switch]$MoveToProgramFiles,

    # Display GPL v3.0 license notice without elevating
    [switch]$License,

    # Display CLI usage help without elevating
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptVersion = 'v1.1.0'
$UninstallRegRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'

# --------------------------------------------------------
# HELPER FUNCTIONS (UI & INPUT)
# --------------------------------------------------------

function Wait-Exit {
    param([switch]$SkipPause)
    if (-not $SkipPause) {
        try {
            $null = Read-Host 'Press Enter to continue'
        } catch {
            # Ignore if stdin is closed or non-interactive
        }
    }
}

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )
    while ($true) {
        try {
            $reply = Read-Host "$Prompt [Y/N]"
        } catch {
            return $false
        }
        if ($null -eq $reply) {
            return $false
        }
        switch -Regex ($reply.Trim()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$'  { return $false }
            default     { Write-Host 'Please enter Y or N.' -ForegroundColor Yellow }
        }
    }
}

function Show-Help {
    $fileName = Split-Path -Leaf $PSCommandPath
    Write-Output "Universal Portable App Installer (Pro Edition $ScriptVersion - PowerShell)"
    Write-Output ''
    Write-Output 'Usage:'
    Write-Output "  powershell -NoProfile -ExecutionPolicy Bypass -File `"$fileName`" [[-AppName] <Name>] [-Exe <File>] [-MoveToProgramFiles] [-Silent] [-License] [-Help]"
    Write-Output ''
    Write-Output 'Parameters:'
    Write-Output '  -AppName <Name>        Display name used for shortcuts and Windows Installed Apps'
    Write-Output '  -Exe <File>            Target executable inside the app folder'
    Write-Output '  -MoveToProgramFiles    Automatically move folder to Program Files (amd64/arm64)'
    Write-Output '    (alias: -Move)       or Program Files (x86) (i386) without prompting'
    Write-Output '  -Silent                Run non-interactively (requires -AppName, and -Exe if multiple EXEs)'
    Write-Output '  -License               Display the GNU GPL v3.0 license notice'
    Write-Output '  -Help                  Show this help message'
}

function Show-License {
    try { Clear-Host } catch {}
    Write-Output '=============================================================================='
    Write-Output ' GNU GENERAL PUBLIC LICENSE'
    Write-Output ' Version 3, 29 June 2007'
    Write-Output ''
    Write-Output ' Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>'
    Write-Output ' Everyone is permitted to copy and distribute verbatim copies'
    Write-Output ' of this license document, but changing it is not allowed.'
    Write-Output '=============================================================================='
    Write-Output ''
    Write-Output 'This program is free software: you can redistribute it and/or modify'
    Write-Output 'it under the terms of the GNU General Public License as published by'
    Write-Output 'the Free Software Foundation, either version 3 of the License, or'
    Write-Output '(at your option) any later version.'
    Write-Output ''
    Write-Output 'This program is distributed in the hope that it will be useful,'
    Write-Output 'but WITHOUT ANY WARRANTY;'
    Write-Output 'without even the implied warranty of'
    Write-Output 'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.'
    Write-Output ''
    Write-Output 'See https://www.gnu.org/licenses/gpl-3.0.txt for the full license.'
    Write-Output '=============================================================================='
    Wait-Exit
}

# --------------------------------------------------------
# PRIVILEGE & ENVIRONMENT CHECKS
# --------------------------------------------------------

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Format-ProcessArgument {
    param([string]$Value)
    # Quote an argument safely for Windows CreateProcess / powershell.exe -File
    if ($null -eq $Value) { return '""' }
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Invoke-SelfElevate {
    param([hashtable]$BoundParams)

    Write-Host '[INFO] Requesting administrator privileges...'
    # Use whichever PowerShell executable is currently running (powershell.exe or pwsh.exe)
    $hostExe = (Get-Process -Id $PID).Path
    $argTokens = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', (Format-ProcessArgument $PSCommandPath)
    )

    if ($BoundParams.ContainsKey('AppName') -and -not [string]::IsNullOrEmpty($BoundParams['AppName'])) {
        $argTokens += '-AppName'
        $argTokens += (Format-ProcessArgument $BoundParams['AppName'])
    }
    if ($BoundParams.ContainsKey('Exe') -and -not [string]::IsNullOrEmpty($BoundParams['Exe'])) {
        $argTokens += '-Exe'
        $argTokens += (Format-ProcessArgument $BoundParams['Exe'])
    }
    if ($BoundParams.ContainsKey('MoveToProgramFiles') -and $BoundParams['MoveToProgramFiles']) {
        $argTokens += '-MoveToProgramFiles'
    }
    if ($BoundParams.ContainsKey('Silent') -and $BoundParams['Silent']) {
        $argTokens += '-Silent'
    }

    try {
        $proc = Start-Process -FilePath $hostExe -ArgumentList ($argTokens -join ' ') -Verb RunAs -Wait -PassThru
        return $proc.ExitCode
    } catch {
        Write-Host '[ERROR] Administrator elevation was cancelled or failed.' -ForegroundColor Red
        return 1
    }
}

# --------------------------------------------------------
# SPLASH SCREEN
# --------------------------------------------------------

function Show-SplashScreen {
    try {
        if ([Console]::LargestWindowHeight -ge 40 -and [Console]::WindowHeight -lt 40) {
            $newWidth = [Math]::Min([Math]::Max([Console]::WindowWidth, 80), [Console]::LargestWindowWidth)
            if ([Console]::BufferWidth -lt $newWidth) { [Console]::BufferWidth = $newWidth }
            if ([Console]::BufferHeight -lt 40) { [Console]::BufferHeight = 40 }
            [Console]::SetWindowSize($newWidth, 40)
        }
        Clear-Host
    } catch {}

    $art = @(
        '888     888          d8b                                             888'
        '888     888          Y8P                                             888'
        '888     888                                                          888'
        '888     888 88888b.  888 888  888  .d88b.  888d888 .d8888b   8888b.  888'
        '888     888 888 "88b 888 888  888 d8P  Y8b 888P"   88K          "88b 888'
        '888     888 888  888 888 Y88  88P 88888888 888     "Y8888b. .d888888 888'
        'Y88b. .d88P 888  888 888  Y8bd8P  Y8b.     888          X88 888  888 888'
        ' "Y88888P"  888  888 888   Y88P    "Y88888 888      88888P'' "Y888888 888'
        '8888888b.                   888             888      888         '
        '888   Y88b                  888             888      888         '
        '888    888                  888             888      888         '
        '888   d88P  .d88b.  888d888 888888  8888b.  88888b.  888  .d88b. '
        '8888888P"  d88""88b 888P"   888        "88b 888 "88b 888 d8P  Y8b'
        '888        888  888 888     888    .d888888 888  888 888 88888888'
        '888        Y88..88P 888     Y88b.  888  888 888 d88P 888 Y8b.    '
        '888         "Y88P"  888      "Y888 "Y888888 88888P"  888  "Y88888'
        '       d8888                           '
        '      d88888                           '
        '     d88P888                           '
        '    d88P 888 88888b.  88888b.  .d8888b '
        '   d88P  888 888 "88b 888 "88b 88K     '
        '  d88P   888 888  888 888  888 "Y8888b.'
        ' d8888888888 888 d88P 888 d88P      X88'
        'd88P     888 88888P"  88888P"   88888P'''
        '             888      888              '
        '             888      888              '
        '             888      888              '
        '8888888                   888             888 888                 '
        '  888                     888             888 888                 '
        '  888                     888             888 888                 '
        '  888   88888b.  .d8888b  888888  8888b.  888 888  .d88b.  888d888'
        '  888   888 "88b 88K      888        "88b 888 888 d8P  Y8b 888P"  '
        '  888   888  888 "Y8888b. 888    .d888888 888 888 88888888 888    '
        '  888   888  888      X88 Y88b.  888  888 888 888 Y8b.     888    '
        '8888888 888  888  88888P''  "Y888 "Y888888 888 888  "Y88888 888    '
    )
    $art | ForEach-Object { Write-Host $_ }
    Write-Host ''

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $width = 36
    $cr = [char]13
    $skipped = $false
    while ($sw.ElapsedMilliseconds -lt 3000) {
        try {
            if ([Console]::KeyAvailable) {
                $null = [Console]::ReadKey($true)
                $skipped = $true
                break
            }
        } catch {}

        $ratio = [Math]::Min(1.0, $sw.ElapsedMilliseconds / 3000.0)
        $filled = [int][Math]::Floor($ratio * $width)
        $bar = ('#' * $filled) + ('-' * ($width - $filled))
        $pct = [int][Math]::Floor($ratio * 100)
        Write-Host -NoNewline ("{0}  Loading [{1}] {2,3}%  (Press any key to skip)" -f $cr, $bar, $pct)
        Start-Sleep -Milliseconds 50
    }
    if (-not $skipped) {
        Write-Host ("{0}  Loading [{1}] 100%  (Press any key to skip)" -f $cr, ('#' * $width))
    } else {
        Write-Host ''
    }
}

# --------------------------------------------------------
# SAFETY & SANITIZATION FUNCTIONS
# --------------------------------------------------------

function Test-IsSafeDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ($Path.StartsWith('\\')) { return $false }

    try {
        $normalized = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    } catch {
        return $false
    }

    if ($normalized.StartsWith('\\')) { return $false }
    # Reject drive roots such as "C:" or invalid short strings
    if ($normalized.Length -le 2) { return $false }

    # Block %SystemRoot% (e.g. C:\Windows) AND any subdirectory inside it (e.g. System32)
    $sysRoot = [Environment]::GetEnvironmentVariable('SystemRoot')
    if ($sysRoot) {
        $sysRootNorm = [IO.Path]::GetFullPath($sysRoot).TrimEnd('\')
        if ($normalized.Equals($sysRootNorm, [StringComparison]::OrdinalIgnoreCase) -or
            $normalized.StartsWith(($sysRootNorm + '\'), [StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    $blockedExact = New-Object System.Collections.Generic.List[string]

    $envNames = @(
        'SystemDrive', 'ProgramFiles', 'ProgramFiles(x86)', 'ProgramW6432',
        'ProgramData', 'USERPROFILE', 'PUBLIC', 'TEMP', 'TMP',
        'APPDATA', 'LOCALAPPDATA'
    )
    foreach ($name in $envNames) {
        $val = [Environment]::GetEnvironmentVariable($name)
        if ($val) { [void]$blockedExact.Add($val) }
    }

    $sysDrive = [Environment]::GetEnvironmentVariable('SystemDrive')
    if ($sysDrive) {
        [void]$blockedExact.Add((Join-Path $sysDrive 'Users'))
    }

    # Include real Windows Shell folders (handles custom/redirected locations like D:\Desktop)
    foreach ($special in @('Desktop', 'DesktopDirectory', 'MyDocuments', 'MyPictures', 'MyMusic', 'MyVideos')) {
        $folderPath = [Environment]::GetFolderPath($special)
        if ($folderPath) { [void]$blockedExact.Add($folderPath) }
    }

    # Also guard standard subfolders under UserProfile and OneDrive variants
    $userBases = New-Object System.Collections.Generic.List[string]
    $userProfile = [Environment]::GetEnvironmentVariable('USERPROFILE')
    if ($userProfile) {
        [void]$userBases.Add($userProfile)
        [void]$userBases.Add((Join-Path $userProfile 'OneDrive'))
    }
    foreach ($odEnv in @('OneDrive', 'OneDriveConsumer', 'OneDriveCommercial')) {
        $odVal = [Environment]::GetEnvironmentVariable($odEnv)
        if ($odVal) { [void]$userBases.Add($odVal) }
    }
    foreach ($base in $userBases) {
        foreach ($sub in @('Desktop', 'Downloads', 'Documents', 'Pictures', 'Music', 'Videos')) {
            [void]$blockedExact.Add((Join-Path $base $sub))
        }
    }

    foreach ($candidate in $blockedExact) {
        try {
            $candNorm = [IO.Path]::GetFullPath($candidate).TrimEnd('\')
            if ($normalized.Equals($candNorm, [StringComparison]::OrdinalIgnoreCase)) {
                return $false
            }
        } catch {}
    }

    return $true
}

function ConvertTo-SafeAppName {
    param([string]$RawName)

    if ([string]::IsNullOrWhiteSpace($RawName)) { return '' }

    # Replace & with 'and', strip filesystem/batch-unsafe characters, trim dots & spaces
    $clean = $RawName -replace '&', 'and'
    $clean = $clean -replace '[\\/:*?"<>|^%!\x00-\x1F]', ''
    $clean = ($clean -replace '\s+', ' ').Trim().TrimEnd('.').Trim()

    # Reject Windows reserved DOS device names
    if ($clean -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') {
        return ''
    }

    return $clean
}

# --------------------------------------------------------
# EXECUTABLE, PE ARCHITECTURE & METADATA FUNCTIONS
# --------------------------------------------------------

function Select-TargetExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDir,
        [string]$PresetExe,
        [switch]$IsSilent
    )

    $baseNorm = [IO.Path]::GetFullPath($AppDir).TrimEnd('\')
    $prefix = $baseNorm + '\'

    if (-not [string]::IsNullOrWhiteSpace($PresetExe)) {
        try {
            $candidate = if ([IO.Path]::IsPathRooted($PresetExe)) {
                [IO.Path]::GetFullPath($PresetExe)
            } else {
                [IO.Path]::GetFullPath((Join-Path $baseNorm $PresetExe))
            }
        } catch {
            throw "Invalid executable path '$PresetExe'."
        }

        if (-not $candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "The specified executable '$PresetExe' must reside inside '$baseNorm'."
        }
        if (-not [IO.File]::Exists($candidate)) {
            throw "The specified executable '$PresetExe' does not exist as a file in '$baseNorm'."
        }

        return [pscustomobject]@{
            RelativePath = $candidate.Substring($prefix.Length)
            FullPath     = $candidate
            FileName     = [IO.Path]::GetFileName($candidate)
        }
    }

    $exeFiles = @(Get-ChildItem -LiteralPath $baseNorm -Filter '*.exe' -File | Sort-Object Name)
    if ($exeFiles.Count -eq 0) {
        throw 'No .exe files found in this directory.'
    }

    if ($exeFiles.Count -eq 1) {
        $chosen = $exeFiles[0]
        return [pscustomobject]@{
            RelativePath = $chosen.Name
            FullPath     = $chosen.FullName
            FileName     = $chosen.Name
        }
    }

    if ($IsSilent) {
        throw 'Multiple executables found, but no -Exe parameter was provided. Cannot guess safely in silent mode.'
    }

    Write-Host ''
    Write-Host 'Multiple executables found:'
    for ($i = 0; $i -lt $exeFiles.Count; $i++) {
        Write-Host ("[{0}] {1}" -f ($i + 1), $exeFiles[$i].Name)
    }

    while ($true) {
        $pick = Read-Host ("Select the number of the main executable (1-{0})" -f $exeFiles.Count)
        $index = 0
        if ([int]::TryParse($pick, [ref]$index) -and $index -ge 1 -and $index -le $exeFiles.Count) {
            $chosen = $exeFiles[$index - 1]
            return [pscustomobject]@{
                RelativePath = $chosen.Name
                FullPath     = $chosen.FullName
                FileName     = $chosen.Name
            }
        }
        Write-Host ("[ERROR] Invalid selection. Please choose a number between 1 and {0}." -f $exeFiles.Count) -ForegroundColor Red
    }
}

function Get-PeArchitecture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath
    )

    try {
        $fs = [IO.File]::OpenRead($ExePath)
        try {
            $br = New-Object IO.BinaryReader($fs)
            # Check DOS header magic ("MZ" = 0x5A4D)
            if ($fs.Length -lt 64 -or $br.ReadUInt16() -ne 0x5A4D) {
                return 'unknown'
            }
            # e_lfanew at offset 0x3C points to the PE signature ("PE\0\0")
            $fs.Position = 60
            $peOffset = $br.ReadUInt32()
            if ($peOffset -gt ($fs.Length - 6)) {
                return 'unknown'
            }
            $fs.Position = $peOffset
            if ($br.ReadUInt32() -ne 0x00004550) {
                return 'unknown'
            }
            # Next UInt16 is the COFF Machine field
            switch ($br.ReadUInt16()) {
                0x8664 { return 'amd64' }
                0x014C { return 'i386' }
                0xAA64 { return 'arm64' }
                default { return 'unknown' }
            }
        } finally {
            $fs.Close()
        }
    } catch {
        return 'unknown'
    }
}

function Get-AppMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath,
        [Parameter(Mandatory = $true)]
        [string]$AppDir
    )

    $arch = Get-PeArchitecture -ExePath $ExePath
    $version = ''
    $publisher = 'Portable App'

    try {
        $vi = [Diagnostics.FileVersionInfo]::GetVersionInfo($ExePath)
        $rawVer = ''
        if ($vi.ProductVersion) { $rawVer = $vi.ProductVersion.Trim() }
        if (-not $rawVer -and $vi.FileVersion) { $rawVer = $vi.FileVersion.Trim() }
        if ($rawVer) {
            $version = ($rawVer -replace '[\r\n\x00-\x1F]', '').Trim()
        }
        if ($vi.CompanyName) {
            $rawPub = ($vi.CompanyName -replace '[\r\n\x00-\x1F]', '').Trim()
            if ($rawPub) { $publisher = $rawPub }
        }
    } catch {}

    # Traverse directory tree iteratively while skipping directory junctions / reparse points
    $totalBytes = [int64]0
    try {
        $stack = New-Object System.Collections.Generic.Stack[string]
        $stack.Push($AppDir)
        while ($stack.Count -gt 0) {
            $current = $stack.Pop()
            try {
                $dirInfo = New-Object IO.DirectoryInfo($current)
                if (($dirInfo.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                foreach ($file in $dirInfo.GetFiles()) {
                    if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
                        $totalBytes += $file.Length
                    }
                }
                foreach ($subDir in $dirInfo.GetDirectories()) {
                    if (($subDir.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
                        $stack.Push($subDir.FullName)
                    }
                }
            } catch {}
        }
    } catch {}

    $sizeKB = [int64][Math]::Min([Math]::Round($totalBytes / 1024.0), [double][uint32]::MaxValue)

    return [pscustomobject]@{
        Architecture = $arch
        Version      = $version
        Publisher    = $publisher
        SizeKB       = $sizeKB
        InstallDate  = (Get-Date).ToString('yyyyMMdd')
    }
}

# --------------------------------------------------------
# MOVE TO PROGRAM FILES, UNINSTALLER, REGISTRY, SHORTCUTS
# --------------------------------------------------------

function Get-ProgramFilesTarget {
    param([string]$Architecture)

    if ($Architecture -eq 'i386') {
        $x86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
        if ($x86) { return $x86.TrimEnd('\') }
    } else {
        $x64 = [Environment]::GetEnvironmentVariable('ProgramW6432')
        if ($x64) { return $x64.TrimEnd('\') }
    }

    $pf = [Environment]::GetEnvironmentVariable('ProgramFiles')
    if ($pf) { return $pf.TrimEnd('\') }

    return (Join-Path ([Environment]::GetEnvironmentVariable('SystemDrive')) 'Program Files')
}

function Move-AppFolderToProgramFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDir,
        [Parameter(Mandatory = $true)]
        [string]$SafeAppName,
        [Parameter(Mandatory = $true)]
        [string]$TargetExeRelative,
        [Parameter(Mandatory = $true)]
        [string]$Architecture,
        [switch]$AutoMove,
        [switch]$IsSilent
    )

    $pfBase = Get-ProgramFilesTarget -Architecture $Architecture
    $destDir = Join-Path $pfBase $SafeAppName

    if ($AppDir.Equals($destDir, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "[INFO] Application is already in `"$destDir`"."
        return [pscustomobject]@{ Moved = $false; AppDir = $AppDir; OldAppDir = '' }
    }

    if (-not $AutoMove) {
        if ($IsSilent) {
            return [pscustomobject]@{ Moved = $false; AppDir = $AppDir; OldAppDir = '' }
        }
        Write-Host ''
        Write-Host "[INFO] Recommended install folder for ${Architecture}: `"$destDir`""
        if (-not (Read-YesNo 'Do you want to move this application folder to Program Files?')) {
            return [pscustomobject]@{ Moved = $false; AppDir = $AppDir; OldAppDir = '' }
        }
        if (Test-Path -LiteralPath $destDir) {
            Write-Host "[WARNING] `"$destDir`" already exists." -ForegroundColor Yellow
            if (-not (Read-YesNo 'Merge/overwrite files into that folder?')) {
                return [pscustomobject]@{ Moved = $false; AppDir = $AppDir; OldAppDir = '' }
            }
        }
    }

    Write-Host "[INFO] Copying files to `"$destDir`"..."
    if (-not (Test-Path -LiteralPath $destDir)) {
        $null = New-Item -ItemType Directory -Path $destDir -Force
    }

    $scriptLeaf = Split-Path -Leaf $PSCommandPath
    & robocopy $AppDir $destDir /E /COPY:DAT /R:2 /W:1 /XF $scriptLeaf /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
    # Robocopy exit codes 0-7 indicate success; 8 or higher indicates failure
    if ($LASTEXITCODE -ge 8) {
        throw "Failed to copy application files to '$destDir' (robocopy exit code $LASTEXITCODE). Original folder was left untouched."
    }

    $destExe = Join-Path $destDir $TargetExeRelative
    if (-not [IO.File]::Exists($destExe)) {
        throw "Verification failed: '$TargetExeRelative' was not found in '$destDir'. Original folder was left untouched."
    }

    return [pscustomobject]@{
        Moved     = $true
        AppDir    = $destDir
        OldAppDir = $AppDir
    }
}

function New-UninstallerScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDir,
        [Parameter(Mandatory = $true)]
        [string]$SafeAppName
    )

    $uninstallerName = 'Uninstall_' + ($SafeAppName -replace ' ', '_') + '.ps1'
    $uninstallerPath = Join-Path $AppDir $uninstallerName
    $escapedName = $SafeAppName -replace "'", "''"

    $content = @"
# Auto-generated uninstaller for $SafeAppName
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'

`$AppName = '$escapedName'
`$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\`$AppName"

function Test-IsAdministrator {
    `$id = [Security.Principal.WindowsIdentity]::GetCurrent()
    `$p = New-Object Security.Principal.WindowsPrincipal(`$id)
    return `$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsSafeDirectory {
    param([string]`$Path)
    if ([string]::IsNullOrWhiteSpace(`$Path) -or `$Path.StartsWith('\\')) { return `$false }
    try { `$norm = [IO.Path]::GetFullPath(`$Path).TrimEnd('\') } catch { return `$false }
    if (`$norm.StartsWith('\\') -or `$norm.Length -le 2) { return `$false }

    `$sysRoot = [Environment]::GetEnvironmentVariable('SystemRoot')
    if (`$sysRoot) {
        `$sysRootNorm = [IO.Path]::GetFullPath(`$sysRoot).TrimEnd('\')
        if (`$norm.Equals(`$sysRootNorm, [StringComparison]::OrdinalIgnoreCase) -or
            `$norm.StartsWith((`$sysRootNorm + '\'), [StringComparison]::OrdinalIgnoreCase)) {
            return `$false
        }
    }

    `$blocked = New-Object System.Collections.Generic.List[string]
    foreach (`$n in @('SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','USERPROFILE','PUBLIC','TEMP','TMP','APPDATA','LOCALAPPDATA')) {
        `$v = [Environment]::GetEnvironmentVariable(`$n)
        if (`$v) { [void]`$blocked.Add(`$v) }
    }
    `$sd = [Environment]::GetEnvironmentVariable('SystemDrive')
    if (`$sd) { [void]`$blocked.Add((Join-Path `$sd 'Users')) }
    foreach (`$sp in @('Desktop','DesktopDirectory','MyDocuments','MyPictures','MyMusic','MyVideos')) {
        `$fp = [Environment]::GetFolderPath(`$sp)
        if (`$fp) { [void]`$blocked.Add(`$fp) }
    }
    `$bases = New-Object System.Collections.Generic.List[string]
    `$up = [Environment]::GetEnvironmentVariable('USERPROFILE')
    if (`$up) { [void]`$bases.Add(`$up); [void]`$bases.Add((Join-Path `$up 'OneDrive')) }
    foreach (`$od in @('OneDrive','OneDriveConsumer','OneDriveCommercial')) {
        `$ov = [Environment]::GetEnvironmentVariable(`$od)
        if (`$ov) { [void]`$bases.Add(`$ov) }
    }
    foreach (`$b in `$bases) {
        foreach (`$s in @('Desktop','Downloads','Documents','Pictures','Music','Videos')) {
            [void]`$blocked.Add((Join-Path `$b `$s))
        }
    }
    foreach (`$c in `$blocked) {
        try {
            if (`$norm.Equals([IO.Path]::GetFullPath(`$c).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
                return `$false
            }
        } catch {}
    }
    return `$true
}

if (-not (Test-IsAdministrator)) {
    Write-Host '[INFO] Requesting administrator privileges...'
    `$hostExe = (Get-Process -Id `$PID).Path
    `$escPath = `$PSCommandPath -replace '(\\*)"', '`$1`$1\"' -replace '(\\+)$', '`$1`$1'
    try {
        `$proc = Start-Process -FilePath `$hostExe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + `$escPath + '"') -Verb RunAs -Wait -PassThru
        exit `$proc.ExitCode
    } catch {
        exit 1
    }
}

Write-Host '=========================================='
Write-Host "   Uninstalling `$AppName"
Write-Host '=========================================='
Write-Host ''

`$confirm = ''
while (`$true) {
    try { `$confirm = Read-Host "Are you sure you want to completely remove `$AppName and all its files? [Y/N]" } catch { exit 0 }
    if (`$null -eq `$confirm) { exit 0 }
    if (`$confirm.Trim() -match '^(y|yes)$') { break }
    if (`$confirm.Trim() -match '^(n|no)$') { exit 0 }
}

`$appDir = `$PSScriptRoot.TrimEnd('\')
if (-not (Test-IsSafeDirectory -Path `$appDir)) {
    Write-Host "[ERROR] Cannot safely uninstall from `"`$appDir`"." -ForegroundColor Red
    try { `$null = Read-Host 'Press Enter to exit' } catch {}
    exit 1
}

Write-Host "[1/5] Stopping running application processes in `"`$appDir`"..."
`$dirPrefix = `$appDir + '\'
Get-Process -ErrorAction SilentlyContinue | Where-Object {
    try { `$_.Path -and `$_.Path.StartsWith(`$dirPrefix, [StringComparison]::OrdinalIgnoreCase) } catch { `$false }
} | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host '[2/5] Removing registry entries...'
if (Test-Path -LiteralPath `$RegPath) {
    Remove-Item -LiteralPath `$RegPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '[3/5] Removing Desktop and Start Menu shortcuts...'
`$lnkName = "`$AppName.lnk"
`$dirs = @(
    [Environment]::GetFolderPath('CommonDesktopDirectory'),
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonPrograms'),
    [Environment]::GetFolderPath('Programs')
)
foreach (`$od in @('OneDrive','OneDriveConsumer','OneDriveCommercial')) {
    `$ov = [Environment]::GetEnvironmentVariable(`$od)
    if (`$ov) { `$dirs += (Join-Path `$ov 'Desktop') }
}
foreach (`$d in (`$dirs | Where-Object { `$_ } | Select-Object -Unique)) {
    `$lnkPath = Join-Path `$d `$lnkName
    if (Test-Path -LiteralPath `$lnkPath) {
        Remove-Item -LiteralPath `$lnkPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host '[4/5] Waiting for file handles to release...'
Start-Sleep -Seconds 2

Write-Host '[5/5] Finalizing folder removal...'
Set-Location -LiteralPath ([IO.Path]::GetTempPath())
Remove-Item -LiteralPath `$appDir -Recurse -Force
exit 0
"@

    Set-Content -LiteralPath $uninstallerPath -Value $content -Encoding ASCII
    return $uninstallerPath
}

function Register-WindowsUninstallEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SafeAppName,
        [Parameter(Mandatory = $true)]
        [string]$AppDir,
        [Parameter(Mandatory = $true)]
        [string]$ExePath,
        [Parameter(Mandatory = $true)]
        [string]$UninstallerPath,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Metadata
    )

    $regPath = Join-Path $UninstallRegRoot $SafeAppName
    $null = New-Item -Path $regPath -Force

    $psExe = 'powershell.exe'
    $uninstallCmd = "$psExe -NoProfile -ExecutionPolicy Bypass -File `"$UninstallerPath`""

    $null = New-ItemProperty -Path $regPath -Name 'DisplayName' -Value $SafeAppName -PropertyType String -Force
    if (-not [string]::IsNullOrWhiteSpace($Metadata.Version)) {
        $null = New-ItemProperty -Path $regPath -Name 'DisplayVersion' -Value $Metadata.Version -PropertyType String -Force
    } else {
        Remove-ItemProperty -Path $regPath -Name 'DisplayVersion' -ErrorAction SilentlyContinue
    }
    $null = New-ItemProperty -Path $regPath -Name 'Publisher' -Value $Metadata.Publisher -PropertyType String -Force
    $null = New-ItemProperty -Path $regPath -Name 'EstimatedSize' -Value ([int]$Metadata.SizeKB) -PropertyType DWord -Force
    $null = New-ItemProperty -Path $regPath -Name 'InstallDate' -Value $Metadata.InstallDate -PropertyType String -Force
    $null = New-ItemProperty -Path $regPath -Name 'UninstallString' -Value $uninstallCmd -PropertyType String -Force
    $null = New-ItemProperty -Path $regPath -Name 'DisplayIcon' -Value "`"$ExePath`",0" -PropertyType String -Force
    $null = New-ItemProperty -Path $regPath -Name 'InstallLocation' -Value $AppDir -PropertyType String -Force
    $null = New-ItemProperty -Path $regPath -Name 'NoModify' -Value 1 -PropertyType DWord -Force
    $null = New-ItemProperty -Path $regPath -Name 'NoRepair' -Value 1 -PropertyType DWord -Force
}

function New-AppShortcuts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SafeAppName,
        [Parameter(Mandatory = $true)]
        [string]$ExePath,
        [Parameter(Mandatory = $true)]
        [string]$AppDir
    )

    # Note: WScript.Shell COM (wshom.ocx) is used strictly to write .lnk files (not VBScript).
    # Folder locations are resolved natively via .NET [Environment]::GetFolderPath.
    $ws = New-Object -ComObject WScript.Shell
    foreach ($folder in @('CommonDesktopDirectory', 'CommonPrograms')) {
        $targetFolder = [Environment]::GetFolderPath($folder)
        if ([string]::IsNullOrWhiteSpace($targetFolder)) {
            throw "Could not resolve special folder '$folder'."
        }
        $lnkPath = Join-Path $targetFolder ($SafeAppName + '.lnk')
        $shortcut = $ws.CreateShortcut($lnkPath)
        $shortcut.TargetPath = $ExePath
        $shortcut.WorkingDirectory = $AppDir
        $shortcut.IconLocation = "$ExePath,0"
        $shortcut.Save()
    }
}

# --------------------------------------------------------
# MAIN EXECUTION FLOW
# --------------------------------------------------------

if ($Help) {
    Show-Help
    exit 0
}
if ($License) {
    Show-License
    exit 0
}

if (-not (Test-IsAdministrator)) {
    $elevatedCode = Invoke-SelfElevate -BoundParams $PSBoundParameters
    exit $elevatedCode
}

$appDir = $PSScriptRoot.TrimEnd('\')
if ($appDir.StartsWith('\\')) {
    Write-Host '[ERROR] Running directly from a network UNC path is not supported.' -ForegroundColor Red
    Write-Host 'Please copy the application folder to a local drive first.'
    Wait-Exit -SkipPause:$Silent
    exit 1
}

Set-Location -LiteralPath $appDir

if (-not $Silent) {
    Show-SplashScreen
}

try { Clear-Host } catch {}
Write-Host '=============================================='
Write-Host '   Universal Portable App Installer'
Write-Host "   Pro Edition $ScriptVersion (PowerShell)"
Write-Host '   Open Source Software by danloGIT/Kardani'
Write-Host '   Licensed under the GNU GPL v3.0'
Write-Host '=============================================='
Write-Host ''

# 1. Directory safety check
if (-not (Test-IsSafeDirectory -Path $appDir)) {
    Write-Host "[ERROR] Cannot install directly from a root, system, or shared user folder (`"$appDir`")." -ForegroundColor Red
    Write-Host 'Please move the application to its own dedicated folder first.'
    Wait-Exit -SkipPause:$Silent
    exit 1
}

# 2. Application name & sanitization
while ([string]::IsNullOrWhiteSpace($AppName)) {
    if ($Silent) {
        Write-Host '[ERROR] Silent mode requires -AppName.' -ForegroundColor Red
        exit 1
    }
    $AppName = Read-Host 'Enter the name of the application'
    if ([string]::IsNullOrWhiteSpace($AppName)) {
        Write-Host '[ERROR] Application name cannot be blank.' -ForegroundColor Red
    }
}

$safeAppName = ConvertTo-SafeAppName -RawName $AppName
if ([string]::IsNullOrWhiteSpace($safeAppName)) {
    Write-Host '[ERROR] Application name is invalid or contains no valid characters.' -ForegroundColor Red
    Wait-Exit -SkipPause:$Silent
    exit 1
}

# 3. Duplicate installation check
$existingRegPath = Join-Path $UninstallRegRoot $safeAppName
if (Test-Path -LiteralPath $existingRegPath) {
    if ($Silent) {
        Write-Host '[INFO] Silent mode active. Overwriting existing installation...'
    } else {
        Write-Host ''
        Write-Host "[WARNING] `"$safeAppName`" is already registered on this system." -ForegroundColor Yellow
        if (-not (Read-YesNo 'Do you want to overwrite/reinstall it?')) {
            Write-Host 'Installation aborted by user.'
            Wait-Exit
            exit 0
        }
        Write-Host 'Proceeding with overwrite...'
        Write-Host ''
    }
}

# 4. Target executable selection
try {
    $selectedExe = Select-TargetExecutable -AppDir $appDir -PresetExe $Exe -IsSilent:$Silent
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Wait-Exit -SkipPause:$Silent
    exit 1
}

$exePath = $selectedExe.FullPath

# 5. Metadata, folder size & PE architecture analysis
Write-Host ''
Write-Host '[INFO] Analyzing application properties...'
$metadata = Get-AppMetadata -ExePath $exePath -AppDir $appDir

Write-Host "[INFO] Target executable: `"$($selectedExe.FileName)`""
Write-Host "[INFO] Architecture: $($metadata.Architecture)"
if ($metadata.Version) {
    Write-Host "[INFO] Version: `"$($metadata.Version)`""
} else {
    Write-Host '[INFO] Version: Not specified'
}
Write-Host "[INFO] Publisher: `"$($metadata.Publisher)`""
Write-Host "[INFO] Estimated size: $($metadata.SizeKB) KB"

# 6. Optional architecture-aware move to Program Files
try {
    $moveResult = Move-AppFolderToProgramFiles `
        -AppDir $appDir `
        -SafeAppName $safeAppName `
        -TargetExeRelative $selectedExe.RelativePath `
        -Architecture $metadata.Architecture `
        -AutoMove:$MoveToProgramFiles `
        -IsSilent:$Silent
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Wait-Exit -SkipPause:$Silent
    exit 1
}

$appDir = $moveResult.AppDir
$exePath = Join-Path $appDir $selectedExe.RelativePath
Set-Location -LiteralPath $appDir

# 7. Create uninstaller, register in Windows, and create All-Users shortcuts
try {
    Write-Host ''
    Write-Host '[1/3] Creating uninstaller script...'
    $uninstallerPath = New-UninstallerScript -AppDir $appDir -SafeAppName $safeAppName

    Write-Host '[2/3] Registering application with Windows...'
    Register-WindowsUninstallEntry `
        -SafeAppName $safeAppName `
        -AppDir $appDir `
        -ExePath $exePath `
        -UninstallerPath $uninstallerPath `
        -Metadata $metadata

    Write-Host '[3/3] Creating shortcuts...'
    New-AppShortcuts -SafeAppName $safeAppName -ExePath $exePath -AppDir $appDir
} catch {
    Write-Host "[ERROR] Installation step failed: $($_.Exception.Message)" -ForegroundColor Red
    Wait-Exit -SkipPause:$Silent
    exit 1
}

Write-Host ''
Write-Host '=========================================='
Write-Host "   Success! $safeAppName installed."
Write-Host "   Location: `"$appDir`""
Write-Host "   Uninstaller: `"$uninstallerPath`""
Write-Host '=========================================='

if ($moveResult.Moved -and $moveResult.OldAppDir) {
    Write-Host "[INFO] Removing original folder `"$($moveResult.OldAppDir)`"..."
    Set-Location -LiteralPath ([IO.Path]::GetTempPath())
    try {
        Remove-Item -LiteralPath $moveResult.OldAppDir -Recurse -Force
    } catch {
        Write-Host "[WARNING] Could not delete original folder `"$($moveResult.OldAppDir)`": $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Wait-Exit -SkipPause:$Silent
exit 0
