@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Universal Portable App Installer (Lite)

:: Copyright (c) 2026 danloGIT/Kardani
:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.

if /I "%~1"=="--license" goto ShowLicense

:: Auto-elevate to Administrator
net session >nul 2>&1
if not errorlevel 1 goto IsElevated
echo [INFO] Requesting administrator privileges...
set "UPAI_SCRIPT=%~f0"
powershell -NoProfile -Command "$q=[char]34; try { $p=Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c '+$q+$q+$env:UPAI_SCRIPT+$q+$q) -Verb RunAs -Wait -PassThru; exit $p.ExitCode } catch { exit 1 }"
exit /b %errorlevel%

:IsElevated
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~0,2%"=="\\" (
    echo [ERROR] Running directly from a network UNC path is not supported.
    pause
    exit /b 1
)
cd /d "%~dp0" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Could not switch working directory to "%~dp0".
    pause
    exit /b 1
)

cls
echo ==============================================
echo    Universal Portable App Installer
echo    Lite Edition v1.0
echo    Open Source Software by danloGIT/Kardani
echo    Licensed under the GNU GPL v3.0
echo ==============================================
echo.

:: 1. Directory safety check
set "APP_DIR=%CD%"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"
call :CheckSafeDir "%APP_DIR%"
if errorlevel 1 (
    echo [ERROR] Please place the application in its own dedicated folder first ^("%APP_DIR%"^).
    pause
    exit /b 1
)

:: 2. Ask for application name & sanitize safely
:AskName
set "APP_NAME="
set /p "APP_NAME=Enter the name of the application: "
if not defined APP_NAME goto AskName

set "SAFE_APP_NAME="
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -Command "$n=$env:APP_NAME -replace '\x26','and'; $n=$n -replace '[\\/:*?\x22\x3C\x3E\x7C\x5E\x25\x21\x00-\x1F]',''; $n=($n -replace '\s+',' ').Trim().TrimEnd('.').Trim(); if($n -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$'){$n=''}; Write-Output ('OK='+$n)"`) do set "SAFE_APP_NAME=%%B"

if not defined SAFE_APP_NAME (
    echo [ERROR] Application name is invalid or contains no valid characters.
    goto AskName
)

:: 3. Select executable
set "count=0"
for %%f in (*.exe) do (
    set /a count+=1
    set "CUR_EXE=%%f"
    call :SetArrayItem EXE_LIST CUR_EXE
)

if %count%==0 (
    echo [ERROR] No .exe files found in this directory.
    pause
    exit /b 1
)

if %count%==1 (
    call :GetArrayItem EXE_LIST 1 TARGET_EXE
    goto ExeSelected
)

echo.
setlocal EnableDelayedExpansion
for /L %%i in (1,1,%count%) do echo [%%i] !EXE_LIST[%%i]!
endlocal

:PickExe
set "CHOICE_VAR="
set /p "CHOICE_VAR=Select the main executable (1-%count%): "
if not defined CHOICE_VAR goto PickExe
set "NON_DIGITS="
setlocal EnableDelayedExpansion
for /f "delims=0123456789" %%D in ("!CHOICE_VAR!") do set "NON_DIGITS=1"
if defined NON_DIGITS (
    endlocal
    goto PickExe
)
if not defined EXE_LIST[!CHOICE_VAR!] (
    endlocal
    goto PickExe
)
endlocal
call :GetArrayItem EXE_LIST %CHOICE_VAR% TARGET_EXE

:ExeSelected
set "EXE_PATH=%APP_DIR%\%TARGET_EXE%"
set "UNINSTALLER_PATH=%APP_DIR%\Uninstall_%SAFE_APP_NAME: =_%.bat"

:: 4. Create uninstaller
echo.
echo [1/3] Creating uninstaller...
(
    echo @echo off
    echo setlocal EnableExtensions DisableDelayedExpansion
    echo title Uninstalling %SAFE_APP_NAME%
    echo.
    echo net session ^>nul 2^>^&1
    echo if not errorlevel 1 goto IsElevated
    echo echo [INFO] Requesting administrator privileges...
    echo set "U=%%~f0"
    echo powershell -NoProfile -Command "$q=[char]34; try { $p=Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c '+$q+$q+$env:U+$q+$q) -Verb RunAs -Wait -PassThru; exit $p.ExitCode } catch { exit 1 }"
    echo exit /b %%errorlevel%%
    echo :IsElevated
    echo.
    echo choice /M "Uninstall %SAFE_APP_NAME% and delete its folder?"
    echo if errorlevel 2 exit /b 0
    echo if not errorlevel 1 exit /b 0
    echo.
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
    echo powershell -NoProfile -Command "$d=$env:APP_DIR.TrimEnd('\')+'\'; Get-Process -ErrorAction SilentlyContinue | Where-Object { try { $_.Path -and $_.Path.StartsWith($d,[StringComparison]::OrdinalIgnoreCase) } catch { $false } } | Stop-Process -Force -ErrorAction SilentlyContinue"
    echo reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /f ^>nul 2^>^&1
    echo set "UNINST_APP_NAME=%SAFE_APP_NAME%"
    echo powershell -NoProfile -Command "$name=$env:UNINST_APP_NAME+'.lnk'; $dirs=@([Environment]::GetFolderPath('CommonDesktopDirectory'),[Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('CommonPrograms'),[Environment]::GetFolderPath('Programs')); if($env:OneDrive){$dirs+=Join-Path $env:OneDrive 'Desktop'}; if($env:OneDriveConsumer){$dirs+=Join-Path $env:OneDriveConsumer 'Desktop'}; if($env:OneDriveCommercial){$dirs+=Join-Path $env:OneDriveCommercial 'Desktop'}; foreach($dir in ($dirs | Where-Object {$_} | Select-Object -Unique)){ $lnk=Join-Path $dir $name; if(Test-Path -LiteralPath $lnk){ Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue } }"
    echo ping -n 3 127.0.0.1 ^>nul
    echo cd /d "%%TEMP%%"
    echo ^(goto^) 2^>nul ^& rmdir /s /q "%%APP_DIR%%" ^& exit /b 0
    echo.
    echo :SafetyError
    echo echo [ERROR] Cannot safely uninstall from "%%APP_DIR%%".
    echo pause
    echo exit /b 1
) > "%UNINSTALLER_PATH%"
if errorlevel 1 goto WriteErr
if not exist "%UNINSTALLER_PATH%" goto WriteErr
goto DoRegister

:WriteErr
echo [ERROR] Failed to write uninstaller "%UNINSTALLER_PATH%".
pause
exit /b 1

:: 5. Register in Windows Installed Apps
:DoRegister
echo [2/3] Registering application...
set "REG_KEY=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%"
reg add "%REG_KEY%" /v "DisplayName" /t REG_SZ /d "%SAFE_APP_NAME%" /f >nul
if errorlevel 1 goto RegErr
reg add "%REG_KEY%" /v "Publisher" /t REG_SZ /d "Portable App" /f >nul
if errorlevel 1 goto RegErr
reg add "%REG_KEY%" /v "UninstallString" /t REG_SZ /d "\"%UNINSTALLER_PATH%\"" /f >nul
if errorlevel 1 goto RegErr
reg add "%REG_KEY%" /v "DisplayIcon" /t REG_SZ /d "\"%EXE_PATH%\",0" /f >nul
if errorlevel 1 goto RegErr
reg add "%REG_KEY%" /v "InstallLocation" /t REG_SZ /d "%APP_DIR%" /f >nul
if errorlevel 1 goto RegErr
reg add "%REG_KEY%" /v "NoModify" /t REG_DWORD /d 1 /f >nul
if errorlevel 1 goto RegErr
reg add "%REG_KEY%" /v "NoRepair" /t REG_DWORD /d 1 /f >nul
if errorlevel 1 goto RegErr
goto DoShortcuts

:RegErr
echo [ERROR] Failed to register application in Windows registry.
pause
exit /b 1

:: 6. Create All-Users Desktop and Start Menu shortcuts
:DoShortcuts
echo [3/3] Creating shortcuts...
:: Note: WScript.Shell COM (wshom.ocx) is used only for .lnk creation (not VBScript).
powershell -NoProfile -Command "try { $ws=New-Object -ComObject WScript.Shell; foreach($f in @('CommonDesktopDirectory','CommonPrograms')){ $dir=[Environment]::GetFolderPath($f); if(-not $dir){throw 'Could not resolve '+$f}; $p=Join-Path $dir ($env:SAFE_APP_NAME+'.lnk'); $s=$ws.CreateShortcut($p); $s.TargetPath=$env:EXE_PATH; $s.WorkingDirectory=$env:APP_DIR; $s.IconLocation=$env:EXE_PATH+',0'; $s.Save() } } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
    echo [ERROR] Failed to create Desktop or Start Menu shortcuts.
    pause
    exit /b 1
)

echo.
echo Done! %SAFE_APP_NAME% has been installed.
pause
exit /b 0

:: --------------------------------------------------------
:: SUBROUTINES
:: --------------------------------------------------------
:SetArrayItem
setlocal EnableDelayedExpansion
for /f delims^=^ eol^= %%V in ("!%~2!") do (
    endlocal
    set "%~1[%count%]=%%V"
    goto :eof
)
endlocal
goto :eof

:GetArrayItem
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
:: LICENSE DISPLAY SECTION
:: --------------------------------------------------------
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
