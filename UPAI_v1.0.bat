@echo off
setlocal enabledelayedexpansion
title Universal Portable App Installer

:: Copyright (c) 2026 danlogit/Kardani
:: This program is free software: you can redistribute it and/or modify
:: it under the terms of the GNU General Public License as published by
:: the Free Software Foundation, either version 3 of the License, or
:: (at your option) any later version.

:: ==========================================
::    QUICK ARGUMENT CHECK
:: ==========================================
if /I "%~1"=="--license" goto ShowLicense

:: ==========================================
::    ADMINISTRATOR PRIVILEGES CHECK
:: ==========================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Requesting administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    exit /b
)

cls
cd /d "%~dp0"

set "SCRIPT_VERSION=v1.0"

:: --------------------------------------------------------
:: ARGUMENT PARSER
:: --------------------------------------------------------
set "SILENT_MODE=0"
:ParseArgs
if "%~1"=="" goto DoneArgs
if /I "%~1"=="--silent" (
    set "SILENT_MODE=1"
    shift
    goto ParseArgs
)
if /I "%~1"=="--exe" (
    set "PRESET_EXE=%~2"
    shift
    shift
    goto ParseArgs
)
:: If it's not a known flag, treat it as the app name
if not defined APP_NAME set "APP_NAME=%~1"
shift
goto ParseArgs
:DoneArgs

echo ==============================================
echo    Universal Portable App Installer
echo    Pro Edition !SCRIPT_VERSION!
echo    Open Source Software by danlogit/Kardani
echo    Licensed under the GNU GPL v3.0
echo ==============================================
echo.

:AskName
if "!APP_NAME!"=="" (
    if "!SILENT_MODE!"=="1" (
        echo [ERROR] Silent mode requires an App Name argument.
        timeout /t 5 >nul
        exit /b 1
    )
    set /p APP_NAME="Enter the name of the application: "
    if "!APP_NAME!"=="" (
        echo [ERROR] Application name cannot be blank.
        goto AskName
    )
)

:: Sanitize APP_NAME to prevent VBScript injection
set "SAFE_APP_NAME=!APP_NAME:"=!"

:: --------------------------------------------------------
:: DIRECTORY SAFETY CHECK
:: --------------------------------------------------------
set "APP_DIR=%CD%"
set "UNSAFE_DIRS=Desktop Downloads Documents Pictures Music Videos"
for %%D in (%UNSAFE_DIRS%) do (
    if /I "!APP_DIR!"=="%USERPROFILE%\%%D" (
        echo [ERROR] Cannot install directly from the user %%D folder.
        echo Please move the application to its own dedicated folder first.
        if "!SILENT_MODE!"=="0" pause
        exit /b 1
    )
)

:: --------------------------------------------------------
:: DUPLICATE INSTALLATION CHECK
:: --------------------------------------------------------
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\!SAFE_APP_NAME!" >nul 2>&1
if !errorlevel! equ 0 (
    if "!SILENT_MODE!"=="1" (
        echo [INFO] Silent mode active. Overwriting existing installation...
    ) else (
        echo.
        echo [WARNING] "!SAFE_APP_NAME!" is already registered on this system.
        choice /M "Do you want to overwrite/reinstall it?"
        if !errorlevel! equ 2 (
            echo Installation aborted by user.
            pause
            exit /b
        )
        echo Proceeding with overwrite...
        echo.
    )
)

:: --------------------------------------------------------
:: EXECUTABLE SELECTION LOGIC
:: --------------------------------------------------------
:: If the user provided the --exe flag, verify it and skip the search
if defined PRESET_EXE (
    if exist "!PRESET_EXE!" (
        set "TARGET_EXE=!PRESET_EXE!"
        echo [INFO] Target executable pre-selected via arguments: !TARGET_EXE!
        goto SkipExeSearch
    ) else (
        echo [ERROR] The specified executable "!PRESET_EXE!" does not exist in this directory.
        if "!SILENT_MODE!"=="0" pause
        exit /b 1
    )
)

:: Otherwise, find executables in the current directory
set count=0
for %%f in (*.exe) do (
    set /a count+=1
    set "EXE_FILE=%%f"
    set "EXE_LIST[!count!]=%%f"
)

if %count%==0 (
    echo [ERROR] No .exe files found in this directory.
    if "!SILENT_MODE!"=="0" pause
    exit /b 1
)

if %count%==1 (
    set "TARGET_EXE=!EXE_FILE!"
) else (
    if "!SILENT_MODE!"=="1" (
        echo [ERROR] Multiple executables found, but no --exe flag was provided.
        echo Cannot safely guess the main executable in silent mode.
        timeout /t 5 >nul
        exit /b 1
    ) else (
        echo.
        echo Multiple executables found:
        for /L %%i in (1,1,%count%) do (
            echo [%%i] !EXE_LIST[%%i]!
        )
        set /p "CHOICE_VAR=Select the number of the main executable: "
        for %%i in (!CHOICE_VAR!) do set "TARGET_EXE=!EXE_LIST[%%i]!"
    )
)
:SkipExeSearch

set "EXE_PATH=%APP_DIR%\%TARGET_EXE%"

:: Sanitize paths for PowerShell (escape single quotes by doubling them)
set "SAFE_EXE_PATH=!EXE_PATH:'=''!"
set "SAFE_APP_DIR=!APP_DIR:'=''!"

:: --------------------------------------------------------
:: VERSION & SIZE DETECTION LOGIC
:: --------------------------------------------------------
echo.
echo [INFO] Analyzing application properties...

:: Get Version
for /f "usebackq tokens=*" %%v in (`powershell -NoProfile -Command "(Get-Item '!SAFE_EXE_PATH!').VersionInfo.ProductVersion"`) do set "RAW_VERSION=%%v"
if "%RAW_VERSION%"=="" (
    set "APP_VERSION=%SCRIPT_VERSION%"
) else (
    set "APP_VERSION=%RAW_VERSION%"
)

:: Get Size in KB
for /f "usebackq" %%s in (`powershell -NoProfile -Command "[math]::Round((Get-ChildItem -Path '!SAFE_APP_DIR!' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1KB)"`) do set "APP_SIZE_KB=%%s"
if "!APP_SIZE_KB!"=="" set "APP_SIZE_KB=0"

echo [INFO] Version identified as: !APP_VERSION!
echo [INFO] Estimated size: !APP_SIZE_KB! KB

:: Set paths for uninstaller
set "UNINSTALLER_NAME=Uninstall_%SAFE_APP_NAME: =_%.bat"
set "UNINSTALLER_PATH=%APP_DIR%\%UNINSTALLER_NAME%"

echo.
echo [1/3] Creating uninstaller script...
(
    echo @echo off
    echo title Uninstalling %SAFE_APP_NAME%
    echo echo ==========================================
    echo echo    Uninstalling %SAFE_APP_NAME%
    echo echo ==========================================
    echo echo.
    echo choice /M "Are you sure you want to completely remove %SAFE_APP_NAME% and all its files?"
    echo if errorlevel 2 exit
    echo echo.
    echo set "APP_DIR=%%~dp0"
    echo if "%%APP_DIR:~-1%%"=="\" set "APP_DIR=%%APP_DIR:~0,-1%%"
    echo.
    echo :: SAFETY CHECKS
    echo if /I "%%APP_DIR%%"=="%%SystemDrive%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%USERPROFILE%%" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%USERPROFILE%%\Desktop" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%USERPROFILE%%\Downloads" goto SafetyError
    echo if /I "%%APP_DIR%%"=="%%USERPROFILE%%\Documents" goto SafetyError
    echo.
    echo :StartUninstall
    echo echo [1/5] Closing application processes...
    echo taskkill /F /IM "%TARGET_EXE%" /T ^>nul 2^>^&1
    echo.
    echo echo [2/5] Removing registry entries...
    echo reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /f ^>nul 2^>^&1
    echo.
    echo echo [3/5] Removing Desktop shortcuts...
    echo for %%%%P in ("%%USERPROFILE%%\Desktop" "%%USERPROFILE%%\OneDrive\Desktop" "%%PUBLIC%%\Desktop"^) do if exist "%%%%~P\%SAFE_APP_NAME%.lnk" del /f /q "%%%%~P\%SAFE_APP_NAME%.lnk"
    echo.
    echo echo [4/5] Removing Start Menu shortcut...
    echo if exist "%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\%SAFE_APP_NAME%.lnk" del /f /q "%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\%SAFE_APP_NAME%.lnk"
    echo.
    echo echo [5/5] Finalizing folder removal...
    echo timeout /t 2 ^>nul
    echo cd /d "%%TEMP%%"
    echo ^(goto^) 2^>nul ^& rmdir /s /q "%%APP_DIR%%"
    echo.
    echo :SafetyError
    echo echo [ERROR] Cannot safely uninstall from this root or shared directory.
    echo pause
    echo exit
) > "%UNINSTALLER_PATH%"

echo [2/3] Registering application with Windows...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /v "DisplayName" /t REG_SZ /d "%SAFE_APP_NAME%" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /v "DisplayVersion" /t REG_SZ /d "!APP_VERSION!" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /v "Publisher" /t REG_SZ /d "danlogit/Kardani" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /v "EstimatedSize" /t REG_DWORD /d !APP_SIZE_KB! /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /v "UninstallString" /t REG_SZ /d "\"%UNINSTALLER_PATH%\"" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /v "DisplayIcon" /t REG_SZ /d "\"%EXE_PATH%\"" /f >nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\%SAFE_APP_NAME%" /v "InstallLocation" /t REG_SZ /d "\"%APP_DIR%\"" /f >nul

echo [3/3] Creating shortcuts via VBScript...
set "VBS_PATH=%TEMP%\CreateShortcuts.vbs"
> "%VBS_PATH%" echo Set oWS = WScript.CreateObject("WScript.Shell")
>> "%VBS_PATH%" echo sDesktop = oWS.SpecialFolders("Desktop") ^& "\%SAFE_APP_NAME%.lnk"
>> "%VBS_PATH%" echo Set oLink1 = oWS.CreateShortcut(sDesktop)
>> "%VBS_PATH%" echo oLink1.TargetPath = "%EXE_PATH%"
>> "%VBS_PATH%" echo oLink1.WorkingDirectory = "%APP_DIR%"
>> "%VBS_PATH%" echo oLink1.Save
>> "%VBS_PATH%" echo sPrograms = oWS.SpecialFolders("Programs") ^& "\%SAFE_APP_NAME%.lnk"
>> "%VBS_PATH%" echo Set oLink2 = oWS.CreateShortcut(sPrograms)
>> "%VBS_PATH%" echo oLink2.TargetPath = "%EXE_PATH%"
>> "%VBS_PATH%" echo oLink2.WorkingDirectory = "%APP_DIR%"
>> "%VBS_PATH%" echo oLink2.Save

cscript //nologo "%VBS_PATH%"
del "%VBS_PATH%"

echo.
echo ==========================================
echo    Success! %SAFE_APP_NAME% installed.
echo ==========================================
:: Skip pause if running in silent mode
if "!SILENT_MODE!"=="0" pause
exit /b

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
without even the implied warranty of
echo MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
echo.
echo See https://www.gnu.org/licenses/gpl-3.0.txt for the full license.
echo ==============================================================================
pause
exit /b