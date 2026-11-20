@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Universal Portable App Installer

:: Copyright (c) 2026 danloGIT/Kardani
:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.

set "SCRIPT_VERSION=v1.1.0"

:: ==========================================
::    CAPTURE ARGUMENTS & PRE-UAC CHECKS
:: ==========================================
set "UPAI_ARGC=0"
:CaptureArgs
if "%~1"=="" goto DoneCaptureArgs
if /I "%~1"=="--license" goto ShowLicense
if /I "%~1"=="--help" goto ShowHelp
if /I "%~1"=="-h" goto ShowHelp
if /I "%~1"=="/?" goto ShowHelp
set /a UPAI_ARGC+=1
set "UPAI_ARG_%UPAI_ARGC%=%~1"
shift
goto CaptureArgs
:DoneCaptureArgs

:: ==========================================
::    ADMINISTRATOR PRIVILEGES CHECK
:: ==========================================
net session >nul 2>&1
if not errorlevel 1 goto IsElevated
echo [INFO] Requesting administrator privileges...
set "UPAI_SCRIPT=%~f0"
powershell -NoProfile -Command "$q=[char]34; $parts=@($q+$env:UPAI_SCRIPT+$q); for($i=1;$i -le [int]$env:UPAI_ARGC;$i++){ $v=[Environment]::GetEnvironmentVariable('UPAI_ARG_'+$i); $parts+=($q+($v -replace $q,('\'+$q))+$q) }; try { $p=Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c '+$q+($parts -join ' ')+$q) -Verb RunAs -Wait -PassThru; exit $p.ExitCode } catch { exit 1 }"
exit /b %errorlevel%

:IsElevated
:: ==========================================
::    WORKING DIRECTORY & UNC CHECK
:: ==========================================
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~0,2%"=="\\" (
    echo [ERROR] Running directly from a network UNC path is not supported.
    echo Please copy the application folder to a local drive first.
    pause
    exit /b 1
)
cd /d "%~dp0" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Could not switch working directory to "%~dp0".
    pause
    exit /b 1
)

:: --------------------------------------------------------
:: ARGUMENT PARSER
:: --------------------------------------------------------
set "SILENT_MODE=0"
set "MOVE_TO_PF=0"
set "APP_NAME="
set "PRESET_EXE="
set "ARG_IDX=0"

:ParseArgs
if %ARG_IDX% geq %UPAI_ARGC% goto DoneArgs
set /a ARG_IDX+=1
call :GetArg %ARG_IDX% CUR_ARG
if not defined CUR_ARG goto ParseArgs

if /I "%CUR_ARG%"=="--silent" set "SILENT_MODE=1" & goto ParseArgs
if /I "%CUR_ARG%"=="--move" set "MOVE_TO_PF=1" & goto ParseArgs
if /I "%CUR_ARG%"=="--exe" goto ParseExeArg
if "%CUR_ARG:~0,1%"=="-" (
    echo [ERROR] Unknown option: "%CUR_ARG%". Run with --help for usage.
    exit /b 1
)
if not defined APP_NAME (
    set "APP_NAME=%CUR_ARG%"
    goto ParseArgs
)
echo [ERROR] Unexpected argument: "%CUR_ARG%". Run with --help for usage.
exit /b 1

:ParseExeArg
if %ARG_IDX% geq %UPAI_ARGC% (
    echo [ERROR] The --exe flag requires a filename argument.
    exit /b 1
)
set /a ARG_IDX+=1
call :GetArg %ARG_IDX% PRESET_EXE
if not defined PRESET_EXE (
    echo [ERROR] The --exe flag requires a filename argument.
    exit /b 1
)
if "%PRESET_EXE:~0,2%"=="--" (
    echo [ERROR] The --exe flag requires a filename argument, got "%PRESET_EXE%".
    exit /b 1
)
goto ParseArgs

:DoneArgs

:: --------------------------------------------------------
:: SPLASH SCREEN (3 SECONDS, SKIPPABLE)
:: --------------------------------------------------------
if "%SILENT_MODE%"=="1" goto SkipSplash

powershell -NoProfile -Command "try { if ([Console]::LargestWindowHeight -ge 40 -and [Console]::WindowHeight -lt 40) { $w=[Math]::Min([Math]::Max([Console]::WindowWidth,80),[Console]::LargestWindowWidth); if([Console]::BufferWidth -lt $w){[Console]::BufferWidth=$w}; if([Console]::BufferHeight -lt 40){[Console]::BufferHeight=40}; [Console]::SetWindowSize($w,40) } } catch {}"

cls
echo 888     888          d8b                                             888
echo 888     888          Y8P                                             888
echo 888     888                                                          888
echo 888     888 88888b.  888 888  888  .d88b.  888d888 .d8888b   8888b.  888
echo 888     888 888 "88b 888 888  888 d8P  Y8b 888P"   88K          "88b 888
echo 888     888 888  888 888 Y88  88P 88888888 888     "Y8888b. .d888888 888
echo Y88b. .d88P 888  888 888  Y8bd8P  Y8b.     888          X88 888  888 888
echo  "Y88888P"  888  888 888   Y88P    "Y88888 888      88888P' "Y888888 888
echo 8888888b.                   888             888      888         
echo 888   Y88b                  888             888      888         
echo 888    888                  888             888      888         
echo 888   d88P  .d88b.  888d888 888888  8888b.  88888b.  888  .d88b. 
echo 8888888P"  d88""88b 888P"   888        "88b 888 "88b 888 d8P  Y8b
echo 888        888  888 888     888    .d888888 888  888 888 88888888
echo 888        Y88..88P 888     Y88b.  888  888 888 d88P 888 Y8b.    
echo 888         "Y88P"  888      "Y888 "Y888888 88888P"  888  "Y88888
echo        d8888                           
echo       d88888                           
echo      d88P888                           
echo     d88P 888 88888b.  88888b.  .d8888b 
echo    d88P  888 888 "88b 888 "88b 88K     
echo   d88P   888 888  888 888  888 "Y8888b.
echo  d8888888888 888 d88P 888 d88P      X88
echo d88P     888 88888P"  88888P"   88888P'
echo              888      888              
echo              888      888              
echo              888      888              
echo 8888888                   888             888 888                 
echo   888                     888             888 888                 
echo   888                     888             888 888                 
echo   888   88888b.  .d8888b  888888  8888b.  888 888  .d88b.  888d888
echo   888   888 "88b 88K      888        "88b 888 888 d8P  Y8b 888P"  
echo   888   888  888 "Y8888b. 888    .d888888 888 888 88888888 888    
echo   888   888  888      X88 Y88b.  888  888 888 888 Y8b.     888    
echo 8888888 888  888  88888P'  "Y888 "Y888888 888 888  "Y88888 888    
echo.
powershell -NoProfile -Command "$sw=[Diagnostics.Stopwatch]::StartNew(); $w=36; $cr=[char]13; $pct=[char]37; $skip=$false; while($sw.ElapsedMilliseconds -lt 3000){ try{if([Console]::KeyAvailable){$null=[Console]::ReadKey($true);$skip=$true;break}}catch{}; $r=[math]::Min(1.0,$sw.ElapsedMilliseconds/3000.0); $f=[math]::Floor($r*$w); $b=([string]'#')*$f+([string]'-')*($w-$f); $p=[math]::Floor($r*100); Write-Host -NoNewline ('{0}  Loading [{1}] {2,3}{3}  (Press any key to skip)' -f $cr,$b,$p,$pct); Start-Sleep -Milliseconds 50 }; if(-not $skip){ Write-Host ('{0}  Loading [{1}] 100{2}  (Press any key to skip)' -f $cr,(([string]'#')*$w),$pct) } else { Write-Host '' }"
:SkipSplash

cls
echo ==============================================
echo    Universal Portable App Installer
echo    Pro Edition %SCRIPT_VERSION% (Batch)
echo    Open Source Software by danloGIT/Kardani
echo    Licensed under the GNU GPL v3.0
echo ==============================================
echo.

:: --------------------------------------------------------
:: DIRECTORY SAFETY CHECK
:: --------------------------------------------------------
set "APP_DIR=%CD%"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"
call :CheckSafeDir "%APP_DIR%"
if errorlevel 1 (
    echo [ERROR] Cannot install directly from a root, system, or shared user folder ^("%APP_DIR%"^).
    echo Please move the application to its own dedicated folder first.
    if "%SILENT_MODE%"=="0" pause
    exit /b 1
)

:: --------------------------------------------------------
:: APPLICATION NAME & SANITIZATION
:: --------------------------------------------------------
:AskName
if defined APP_NAME goto HaveAppName
if "%SILENT_MODE%"=="1" (
    echo [ERROR] Silent mode requires an App Name argument.
    exit /b 1
)
set /p "APP_NAME=Enter the name of the application: "
if not defined APP_NAME (
    echo [ERROR] Application name cannot be blank.
    goto AskName
)

:HaveAppName
set "SAFE_APP_NAME="
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -Command "$n=$env:APP_NAME -replace '\x26','and'; $n=$n -replace '[\\/:*?\x22\x3C\x3E\x7C\x5E\x25\x21\x00-\x1F]',''; $n=($n -replace '\s+',' ').Trim().TrimEnd('.').Trim(); if($n -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$'){$n=''}; Write-Output ('OK='+$n)"`) do set "SAFE_APP_NAME=%%B"

if not defined SAFE_APP_NAME (
    echo [ERROR] Application name is invalid or contains no valid characters.
    if "%SILENT_MODE%"=="0" pause
    exit /b 1
)

:: --------------------------------------------------------
:: DUPLICATE INSTALLATION CHECK
:: --------------------------------------------------------
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" >nul 2>&1
if errorlevel 1 goto ExeSelection

if "%SILENT_MODE%"=="1" (
    echo [INFO] Silent mode active. Overwriting existing installation...
    goto ExeSelection
)
echo.
echo [WARNING] "%SAFE_APP_NAME%" is already registered on this system.
choice /M "Do you want to overwrite/reinstall it?"
if errorlevel 2 goto AbortInstall
if not errorlevel 1 goto AbortInstall
echo Proceeding with overwrite...
echo.
goto ExeSelection

:AbortInstall
echo Installation aborted by user.
pause
exit /b 0

:: --------------------------------------------------------
:: EXECUTABLE SELECTION LOGIC
:: --------------------------------------------------------
:ExeSelection
if not defined PRESET_EXE goto ScanExecutables

set "EXE_STATUS="
set "TARGET_EXE="
set "EXE_PATH="
set "TARGET_EXE_NAME="
for /f "usebackq tokens=1-4 delims=|" %%A in (`powershell -NoProfile -Command "$base=[IO.Path]::GetFullPath($env:APP_DIR).TrimEnd('\'); $cand=$env:PRESET_EXE; try{ if([IO.Path]::IsPathRooted($cand)){$full=[IO.Path]::GetFullPath($cand)}else{$full=[IO.Path]::GetFullPath((Join-Path $base $cand))} }catch{ Write-Output 'INVALID'; exit 0 }; $prefix=$base+'\'; if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){ Write-Output 'OUTSIDE'; exit 0 }; if(-not [IO.File]::Exists($full)){ Write-Output 'NOTFOUND'; exit 0 }; $rel=$full.Substring($prefix.Length); $name=[IO.Path]::GetFileName($full); Write-Output ('OK|'+$rel+'|'+$full+'|'+$name)"`) do (
    set "EXE_STATUS=%%A"
    set "TARGET_EXE=%%B"
    set "EXE_PATH=%%C"
    set "TARGET_EXE_NAME=%%D"
)
if /I "%EXE_STATUS%"=="OK" (
    echo [INFO] Target executable pre-selected via arguments: "%TARGET_EXE%"
    goto SkipExeSearch
)
if /I "%EXE_STATUS%"=="OUTSIDE" (
    echo [ERROR] The specified executable "%PRESET_EXE%" must reside inside "%APP_DIR%".
) else (
    echo [ERROR] The specified executable "%PRESET_EXE%" does not exist as a file in "%APP_DIR%".
)
if "%SILENT_MODE%"=="0" pause
exit /b 1

:ScanExecutables
set "count=0"
for %%f in (*.exe) do (
    set /a count+=1
    set "CUR_EXE=%%f"
    call :SetArrayItem EXE_LIST CUR_EXE
)

if %count%==0 (
    echo [ERROR] No .exe files found in this directory.
    if "%SILENT_MODE%"=="0" pause
    exit /b 1
)

if %count%==1 (
    call :GetArrayItem EXE_LIST 1 TARGET_EXE
    goto BuildExePaths
)

if "%SILENT_MODE%"=="1" (
    echo [ERROR] Multiple executables found, but no --exe flag was provided.
    echo Cannot safely guess the main executable in silent mode.
    exit /b 1
)

echo.
echo Multiple executables found:
setlocal EnableDelayedExpansion
for /L %%i in (1,1,%count%) do echo [%%i] !EXE_LIST[%%i]!
endlocal

:SelectExePrompt
set "CHOICE_VAR="
set /p "CHOICE_VAR=Select the number of the main executable (1-%count%): "
if not defined CHOICE_VAR (
    echo [ERROR] Please enter a valid number.
    goto SelectExePrompt
)
set "NON_DIGITS="
setlocal EnableDelayedExpansion
for /f "delims=0123456789" %%D in ("!CHOICE_VAR!") do set "NON_DIGITS=1"
if defined NON_DIGITS (
    endlocal
    echo [ERROR] Invalid selection. Please choose a number between 1 and %count%.
    goto SelectExePrompt
)
if not defined EXE_LIST[!CHOICE_VAR!] (
    endlocal
    echo [ERROR] Invalid selection. Please choose a number between 1 and %count%.
    goto SelectExePrompt
)
endlocal
call :GetArrayItem EXE_LIST %CHOICE_VAR% TARGET_EXE

:BuildExePaths
set "EXE_PATH=%APP_DIR%\%TARGET_EXE%"
for %%I in ("%EXE_PATH%") do set "TARGET_EXE_NAME=%%~nxI"

:SkipExeSearch

:: --------------------------------------------------------
:: METADATA, SIZE & PE ARCHITECTURE DETECTION
:: --------------------------------------------------------
echo.
echo [INFO] Analyzing application properties...

set "PE_ARCH=unknown"
set "APP_VERSION="
set "APP_PUBLISHER=Portable App"
set "APP_SIZE_KB=0"
set "INSTALL_DATE="

for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -Command "$arch='unknown'; try { $fs=[IO.File]::OpenRead($env:EXE_PATH); try { $br=New-Object IO.BinaryReader($fs); if($fs.Length -ge 64 -and $br.ReadUInt16() -eq 0x5A4D){ $fs.Position=60; $pe=$br.ReadUInt32(); if($pe -le ($fs.Length - 6)){ $fs.Position=$pe; if($br.ReadUInt32() -eq 0x00004550){ switch($br.ReadUInt16()){ 0x8664 {$arch='amd64'} 0x014C {$arch='i386'} 0xAA64 {$arch='arm64'} } } } } } finally { $fs.Close() } } catch {}; $ver=''; $pub='Portable App'; try { $vi=[Diagnostics.FileVersionInfo]::GetVersionInfo($env:EXE_PATH); $v=''; if($vi.ProductVersion){$v=$vi.ProductVersion.Trim()}; if(-not $v -and $vi.FileVersion){$v=$vi.FileVersion.Trim()}; if($v){$ver=($v -replace '[\r\n\x00-\x1F\x22]','').Trim()}; if($vi.CompanyName){$c=($vi.CompanyName -replace '[\r\n\x00-\x1F\x22]','').Trim(); if($c){$pub=$c}} } catch {}; $bytes=[int64]0; try { $stack=New-Object System.Collections.Generic.Stack[string]; $stack.Push($env:APP_DIR); while($stack.Count -gt 0){ $d=$stack.Pop(); try { $di=New-Object IO.DirectoryInfo($d); if(($di.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){continue}; foreach($f in $di.GetFiles()){ if(($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0){$bytes+=$f.Length} }; foreach($sd in $di.GetDirectories()){ if(($sd.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0){$stack.Push($sd.FullName)} } } catch {} } } catch {}; $kb=[Math]::Min([int64][Math]::Round($bytes / 1024.0),[int64][uint32]::MaxValue); $dt=(Get-Date).ToString('yyyyMMdd'); Write-Output ('PE_ARCH='+$arch); Write-Output ('APP_VERSION='+$ver); Write-Output ('APP_PUBLISHER='+$pub); Write-Output ('APP_SIZE_KB='+$kb); Write-Output ('INSTALL_DATE='+$dt)"`) do (
    set "%%A=%%B"
)

if not defined PE_ARCH set "PE_ARCH=unknown"
if not defined APP_PUBLISHER set "APP_PUBLISHER=Portable App"
if not defined APP_SIZE_KB set "APP_SIZE_KB=0"

echo [INFO] Target executable: "%TARGET_EXE_NAME%"
echo [INFO] Architecture: %PE_ARCH%
if defined APP_VERSION (
    echo [INFO] Version: "%APP_VERSION%"
) else (
    echo [INFO] Version: Not specified
)
echo [INFO] Publisher: "%APP_PUBLISHER%"
echo [INFO] Estimated size: %APP_SIZE_KB% KB

:: --------------------------------------------------------
:: OPTIONAL ARCH-AWARE MOVE TO PROGRAM FILES
:: --------------------------------------------------------
set "MOVED_FOLDER=0"
set "OLD_APP_DIR="

set "PF_BASE=%ProgramW6432%"
if not defined PF_BASE set "PF_BASE=%ProgramFiles%"
if /I not "%PE_ARCH%"=="i386" goto PfBaseResolved
if defined ProgramFiles(x86) set "PF_BASE=%ProgramFiles(x86)%"
:PfBaseResolved
if "%PF_BASE:~-1%"=="\" set "PF_BASE=%PF_BASE:~0,-1%"
set "DEST_DIR=%PF_BASE%\%SAFE_APP_NAME%"

if /I "%APP_DIR%"=="%DEST_DIR%" (
    echo [INFO] Application is already in "%DEST_DIR%".
    goto SkipMoveToProgramFiles
)

if "%MOVE_TO_PF%"=="1" goto DoMoveToProgramFiles
if "%SILENT_MODE%"=="1" goto SkipMoveToProgramFiles

echo.
echo [INFO] Recommended install folder for %PE_ARCH%: "%DEST_DIR%"
choice /M "Do you want to move this application folder to Program Files?"
if errorlevel 2 goto SkipMoveToProgramFiles
if not errorlevel 1 goto SkipMoveToProgramFiles

if not exist "%DEST_DIR%\" goto DoMoveToProgramFiles
echo [WARNING] "%DEST_DIR%" already exists.
choice /M "Merge/overwrite files into that folder?"
if errorlevel 2 goto SkipMoveToProgramFiles
if not errorlevel 1 goto SkipMoveToProgramFiles

:DoMoveToProgramFiles
echo [INFO] Copying files to "%DEST_DIR%"...
if not exist "%DEST_DIR%\" mkdir "%DEST_DIR%" >nul 2>&1
if not exist "%DEST_DIR%\" (
    echo [ERROR] Could not create destination folder "%DEST_DIR%".
    if "%SILENT_MODE%"=="0" pause
    exit /b 1
)
robocopy "%APP_DIR%" "%DEST_DIR%" /E /COPY:DAT /R:2 /W:1 /XF "%~nx0" /NFL /NDL /NJH /NJS /NC /NS /NP >nul
if errorlevel 8 (
    echo [ERROR] Failed to copy application files to "%DEST_DIR%". Original folder was left untouched.
    if "%SILENT_MODE%"=="0" pause
    exit /b 1
)
if not exist "%DEST_DIR%\%TARGET_EXE%" (
    echo [ERROR] Verification failed: "%TARGET_EXE%" was not found in "%DEST_DIR%". Original folder was left untouched.
    if "%SILENT_MODE%"=="0" pause
    exit /b 1
)

set "OLD_APP_DIR=%APP_DIR%"
set "MOVED_FOLDER=1"
set "APP_DIR=%DEST_DIR%"
set "EXE_PATH=%DEST_DIR%\%TARGET_EXE%"
cd /d "%APP_DIR%" >nul 2>&1

:SkipMoveToProgramFiles

:: --------------------------------------------------------
:: STEP 1/3: CREATE UNINSTALLER
:: --------------------------------------------------------
set "UNINSTALLER_NAME=Uninstall_%SAFE_APP_NAME: =_%.bat"
set "UNINSTALLER_PATH=%APP_DIR%\%UNINSTALLER_NAME%"

echo.
echo [1/3] Creating uninstaller script...
(
    echo @echo off
    echo setlocal EnableExtensions DisableDelayedExpansion
    echo title Uninstalling %SAFE_APP_NAME%
    echo.
    echo :: Ensure Administrator privileges for HKLM registry cleanup and folder removal
    echo net session ^>nul 2^>^&1
    echo if not errorlevel 1 goto IsElevated
    echo echo [INFO] Requesting administrator privileges...
    echo set "UNINST_SCRIPT=%%~f0"
    echo powershell -NoProfile -Command "$q=[char]34; try { $p=Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c '+$q+$q+$env:UNINST_SCRIPT+$q+$q) -Verb RunAs -Wait -PassThru; exit $p.ExitCode } catch { exit 1 }"
    echo exit /b %%errorlevel%%
    echo :IsElevated
    echo.
    echo echo ==========================================
    echo echo    Uninstalling %SAFE_APP_NAME%
    echo echo ==========================================
    echo echo.
    echo choice /M "Are you sure you want to completely remove %SAFE_APP_NAME% and all its files?"
    echo if errorlevel 2 exit /b 0
    echo if not errorlevel 1 exit /b 0
    echo echo.
    echo set "APP_DIR=%%~dp0"
    echo if "%%APP_DIR:~-1%%"=="\" set "APP_DIR=%%APP_DIR:~0,-1%%"
    echo.
    echo :: Directory safety checks
    echo if "%%APP_DIR%%"=="" goto SafetyError
    echo if "%%APP_DIR:~0,2%%"=="\\" goto SafetyError
    echo if "%%APP_DIR:~2%%"=="" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%SystemDrive%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%SystemDrive%%\Users" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%ProgramFiles%%" goto SafetyError
    echo if defined ProgramW6432 if /I "%%APP_DIR%%"=="%%ProgramW6432%%" goto SafetyError
    echo if defined ProgramFiles^(x86^) if /I "%%APP_DIR%%"=="%%ProgramFiles(x86)%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%ProgramData%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%USERPROFILE%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%PUBLIC%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%TEMP%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%TMP%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%APPDATA%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%LOCALAPPDATA%%" goto SafetyError
    echo.
    echo set "SYSROOT=%%SystemRoot%%"
    echo if "%%SYSROOT:~-1%%"=="\" set "SYSROOT=%%SYSROOT:~0,-1%%"
    echo set "WALK=%%APP_DIR%%"
    echo :WinRootLoop
    echo if /I "%%WALK%%"=="%%SYSROOT%%" goto SafetyError
    echo for %%%%P in ^("%%WALK%%\.."^) do set "NEXT_WALK=%%%%~fP"
    echo if "%%NEXT_WALK:~-1%%"=="\" set "NEXT_WALK=%%NEXT_WALK:~0,-1%%"
    echo if /I "%%NEXT_WALK%%"=="%%WALK%%" goto UserRootChecks
    echo set "WALK=%%NEXT_WALK%%"
    echo goto WinRootLoop
    echo.
    echo :UserRootChecks
    echo for %%%%R in ^("%%USERPROFILE%%" "%%USERPROFILE%%\OneDrive" "%%OneDrive%%" "%%OneDriveConsumer%%" "%%OneDriveCommercial%%"^) do ^(
    echo     if not "%%%%~R"=="" ^(
    echo         for %%%%D in ^(Desktop Downloads Documents Pictures Music Videos^) do ^(
    echo             if /I "%%APP_DIR%%"=="%%%%~R\%%%%D" goto SafetyError
    echo         ^)
    echo     ^)
    echo ^)
    echo powershell -NoProfile -Command "$d=$env:APP_DIR.TrimEnd('\'); foreach($k in @('Desktop','DesktopDirectory','MyDocuments','MyPictures','MyMusic','MyVideos')){ $p=[Environment]::GetFolderPath($k).TrimEnd('\'); if($p -and $p -ieq $d){ exit 1 } }; exit 0"
    echo if errorlevel 1 goto SafetyError
    echo.
    echo echo [1/5] Stopping running application processes in "%%APP_DIR%%"...
    echo powershell -NoProfile -Command "$d=$env:APP_DIR.TrimEnd('\')+'\'; Get-Process -ErrorAction SilentlyContinue | Where-Object { try { $_.Path -and $_.Path.StartsWith($d,[StringComparison]::OrdinalIgnoreCase) } catch { $false } } | Stop-Process -Force -ErrorAction SilentlyContinue"
    echo.
    echo echo [2/5] Removing registry entries...
    echo reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /f ^>nul 2^>^&1
    echo.
    echo echo [3/5] Removing Desktop and Start Menu shortcuts...
    echo set "UNINST_APP_NAME=%SAFE_APP_NAME%"
    echo powershell -NoProfile -Command "$name=$env:UNINST_APP_NAME+'.lnk'; $dirs=@([Environment]::GetFolderPath('CommonDesktopDirectory'),[Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('CommonPrograms'),[Environment]::GetFolderPath('Programs')); if($env:OneDrive){$dirs+=Join-Path $env:OneDrive 'Desktop'}; if($env:OneDriveConsumer){$dirs+=Join-Path $env:OneDriveConsumer 'Desktop'}; if($env:OneDriveCommercial){$dirs+=Join-Path $env:OneDriveCommercial 'Desktop'}; foreach($dir in ($dirs | Where-Object {$_} | Select-Object -Unique)){ $lnk=Join-Path $dir $name; if(Test-Path -LiteralPath $lnk){ Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue } }"
    echo.
    echo echo [4/5] Waiting for file handles to release...
    echo ping -n 3 127.0.0.1 ^>nul
    echo.
    echo echo [5/5] Finalizing folder removal...
    echo cd /d "%%TEMP%%"
    echo ^(goto^) 2^>nul ^& rmdir /s /q "%%APP_DIR%%" ^& exit /b 0
    echo.
    echo :SafetyError
    echo echo [ERROR] Cannot safely uninstall from "%%APP_DIR%%".
    echo pause
    echo exit /b 1
) > "%UNINSTALLER_PATH%"
if errorlevel 1 goto UninstallerWriteError
if not exist "%UNINSTALLER_PATH%" goto UninstallerWriteError
goto RegisterApp

:UninstallerWriteError
echo [ERROR] Failed to write uninstaller script "%UNINSTALLER_PATH%".
if "%SILENT_MODE%"=="0" pause
exit /b 1

:: --------------------------------------------------------
:: STEP 2/3: REGISTER IN WINDOWS INSTALLED APPS
:: --------------------------------------------------------
:RegisterApp
echo [2/3] Registering application with Windows...
set "REG_KEY=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%"
reg add "%REG_KEY%" /v "DisplayName" /t REG_SZ /d "%SAFE_APP_NAME%" /f >nul
if errorlevel 1 goto RegError
if not defined APP_VERSION goto SkipDisplayVersion
reg add "%REG_KEY%" /v "DisplayVersion" /t REG_SZ /d "%APP_VERSION%" /f >nul
if errorlevel 1 goto RegError
:SkipDisplayVersion
reg add "%REG_KEY%" /v "Publisher" /t REG_SZ /d "%APP_PUBLISHER%" /f >nul
if errorlevel 1 goto RegError
reg add "%REG_KEY%" /v "EstimatedSize" /t REG_DWORD /d %APP_SIZE_KB% /f >nul
if errorlevel 1 goto RegError
reg add "%REG_KEY%" /v "InstallDate" /t REG_SZ /d "%INSTALL_DATE%" /f >nul
if errorlevel 1 goto RegError
reg add "%REG_KEY%" /v "UninstallString" /t REG_SZ /d "\"%UNINSTALLER_PATH%\"" /f >nul
if errorlevel 1 goto RegError
reg add "%REG_KEY%" /v "DisplayIcon" /t REG_SZ /d "\"%EXE_PATH%\",0" /f >nul
if errorlevel 1 goto RegError
reg add "%REG_KEY%" /v "InstallLocation" /t REG_SZ /d "%APP_DIR%" /f >nul
if errorlevel 1 goto RegError
reg add "%REG_KEY%" /v "NoModify" /t REG_DWORD /d 1 /f >nul
if errorlevel 1 goto RegError
reg add "%REG_KEY%" /v "NoRepair" /t REG_DWORD /d 1 /f >nul
if errorlevel 1 goto RegError
goto CreateShortcuts

:RegError
echo [ERROR] Failed to write Windows Uninstall registry entries.
if "%SILENT_MODE%"=="0" pause
exit /b 1

:: --------------------------------------------------------
:: STEP 3/3: CREATE ALL-USERS SHORTCUTS
:: --------------------------------------------------------
:CreateShortcuts
echo [3/3] Creating shortcuts...
:: Note: WScript.Shell COM (wshom.ocx) is used only for .lnk creation (not VBScript).
:: Folder paths are resolved via .NET [Environment]::GetFolderPath.
powershell -NoProfile -Command "try { $ws=New-Object -ComObject WScript.Shell; foreach($f in @('CommonDesktopDirectory','CommonPrograms')){ $dir=[Environment]::GetFolderPath($f); if(-not $dir){throw 'Could not resolve '+$f}; $p=Join-Path $dir ($env:SAFE_APP_NAME+'.lnk'); $s=$ws.CreateShortcut($p); $s.TargetPath=$env:EXE_PATH; $s.WorkingDirectory=$env:APP_DIR; $s.IconLocation=$env:EXE_PATH+',0'; $s.Save() } } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
    echo [ERROR] Failed to create Desktop or Start Menu shortcuts.
    if "%SILENT_MODE%"=="0" pause
    exit /b 1
)

echo.
echo ==========================================
echo    Success! %SAFE_APP_NAME% installed.
echo    Location: "%APP_DIR%"
echo    Uninstaller: "%UNINSTALLER_PATH%"
echo ==========================================

if not "%MOVED_FOLDER%"=="1" goto DoneNoMove
echo [INFO] Removing original folder "%OLD_APP_DIR%"...
cd /d "%TEMP%"
if "%SILENT_MODE%"=="1" goto FinishMoveSilent
goto FinishMoveInteractive

:DoneNoMove
if "%SILENT_MODE%"=="0" pause
exit /b 0

:FinishMoveInteractive
(goto) 2>nul & rmdir /s /q "%OLD_APP_DIR%" & pause & exit /b 0

:FinishMoveSilent
(goto) 2>nul & rmdir /s /q "%OLD_APP_DIR%" & exit /b 0

:: --------------------------------------------------------
:: SUBROUTINES
:: --------------------------------------------------------
:GetArg
:: Usage: call :GetArg INDEX OUT_VAR
set "%~2="
setlocal EnableDelayedExpansion
for /f delims^=^ eol^= %%V in ("!UPAI_ARG_%~1!") do (
    endlocal
    set "%~2=%%V"
    goto :eof
)
endlocal
goto :eof

:SetArrayItem
:: Usage: call :SetArrayItem ARRAY_NAME VALUE_VAR_NAME (uses %count%)
setlocal EnableDelayedExpansion
for /f delims^=^ eol^= %%V in ("!%~2!") do (
    endlocal
    set "%~1[%count%]=%%V"
    goto :eof
)
endlocal
goto :eof

:GetArrayItem
:: Usage: call :GetArrayItem ARRAY_NAME INDEX OUT_VAR
set "%~3="
setlocal EnableDelayedExpansion
for /f delims^=^ eol^= %%V in ("!%~1[%~2]!") do (
    endlocal
    set "%~3=%%V"
    goto :eof
)
endlocal
goto :eof

:CheckSafeDir
:: Returns exit code 0 if safe, 1 if unsafe
setlocal EnableExtensions DisableDelayedExpansion
set "CHECK_DIR=%~1"
if not defined CHECK_DIR exit /b 1
if "%CHECK_DIR:~-1%"=="\" set "CHECK_DIR=%CHECK_DIR:~0,-1%"
if "%CHECK_DIR:~0,2%"=="\\" exit /b 1
if "%CHECK_DIR:~2%"=="" exit /b 1
if /I "%CHECK_DIR%"=="%SystemDrive%" exit /b 1
if /I "%CHECK_DIR%"=="%SystemDrive%\Users" exit /b 1
if /I "%CHECK_DIR%"=="%ProgramFiles%" exit /b 1
if defined ProgramW6432 if /I "%CHECK_DIR%"=="%ProgramW6432%" exit /b 1
if defined ProgramFiles(x86) if /I "%CHECK_DIR%"=="%ProgramFiles(x86)%" exit /b 1
if /I "%CHECK_DIR%"=="%ProgramData%" exit /b 1
if /I "%CHECK_DIR%"=="%USERPROFILE%" exit /b 1
if /I "%CHECK_DIR%"=="%PUBLIC%" exit /b 1
if /I "%CHECK_DIR%"=="%TEMP%" exit /b 1
if /I "%CHECK_DIR%"=="%TMP%" exit /b 1
if /I "%CHECK_DIR%"=="%APPDATA%" exit /b 1
if /I "%CHECK_DIR%"=="%LOCALAPPDATA%" exit /b 1

set "SYSROOT=%SystemRoot%"
if "%SYSROOT:~-1%"=="\" set "SYSROOT=%SYSROOT:~0,-1%"
set "WALK=%CHECK_DIR%"
:WinRootWalkLoop
if /I "%WALK%"=="%SYSROOT%" exit /b 1
for %%P in ("%WALK%\..") do set "NEXT_WALK=%%~fP"
if "%NEXT_WALK:~-1%"=="\" set "NEXT_WALK=%NEXT_WALK:~0,-1%"
if /I "%NEXT_WALK%"=="%WALK%" goto CheckUserKnownFolders
set "WALK=%NEXT_WALK%"
goto WinRootWalkLoop

:CheckUserKnownFolders
for %%R in ("%USERPROFILE%" "%USERPROFILE%\OneDrive" "%OneDrive%" "%OneDriveConsumer%" "%OneDriveCommercial%") do (
    if not "%%~R"=="" (
        for %%D in (Desktop Downloads Documents Pictures Music Videos) do (
            if /I "%CHECK_DIR%"=="%%~R\%%D" exit /b 1
        )
    )
)
powershell -NoProfile -Command "$d=$env:CHECK_DIR.TrimEnd('\'); foreach($k in @('Desktop','DesktopDirectory','MyDocuments','MyPictures','MyMusic','MyVideos')){ $p=[Environment]::GetFolderPath($k).TrimEnd('\'); if($p -and $p -ieq $d){ exit 1 } }; exit 0"
if errorlevel 1 exit /b 1
exit /b 0

:: --------------------------------------------------------
:: HELP & LICENSE SECTIONS
:: --------------------------------------------------------
:ShowHelp
echo Universal Portable App Installer (Pro Edition %SCRIPT_VERSION%)
echo.
echo Usage:
echo   %~nx0 [AppName] [--exe ^<file^>] [--move] [--silent] [--license] [--help]
echo.
echo Options:
echo   AppName        Display name used for shortcuts and Windows Installed Apps
echo   --exe ^<file^>   Target executable inside the app folder
echo   --move         Automatically move the folder to Program Files (amd64/arm64)
echo                  or Program Files (x86) (i386) without prompting
echo   --silent       Run non-interactively (requires AppName, and --exe if multiple EXEs)
echo   --license      Display the GNU GPL v3.0 license notice
echo   --help, -h     Show this help message
exit /b 0

:ShowLicense
cls
echo ==============================================================================
echo  GNU GENERAL PUBLIC LICENSE
echo  Version 3, 29 June 2007
echo.
echo  Copyright (C) 2007 Free Software Foundation, Inc. ^<https://fsf.org/^>
echo  Everyone is permitted to copy and distribute verbatim copies
echo  of this license document, but changing it is not allowed.
echo ==============================================================================
echo.
echo This program is free software: you can redistribute it and/or modify
echo it under the terms of the GNU General Public License as published by
echo the Free Software Foundation, either version 3 of the License, or
echo (at your option) any later version.
echo.
echo This program is distributed in the hope that it will be useful,
echo but WITHOUT ANY WARRANTY;
echo without even the implied warranty of
echo MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
echo.
echo See https://www.gnu.org/licenses/gpl-3.0.txt for the full license.
echo ==============================================================================
pause
exit /b 0
