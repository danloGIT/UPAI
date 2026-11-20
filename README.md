# Universal Portable App Installer (UPAI)

![OS: Windows](https://img.shields.io/badge/OS-Windows_10%20|%2011-0078D6?style=flat-square&logo=windows&logoColor=white)
![Language: Batch/PowerShell](https://img.shields.io/badge/Language-Batch%20|%20PowerShell-4D4D4D?style=flat-square&logo=powershell&logoColor=white)
![Version](https://img.shields.io/badge/Version-1.1.0_(Stable)-brightgreen?style=flat-square)
![License](https://img.shields.io/badge/License-GPL_v3.0-orange?style=flat-square)

**Author:** [danloGIT/Kardani](https://github.com/danloGIT)  

-----

## What is this?

Portable apps are great because they don't clutter your system, but they usually lack basic Windows integration - no Start Menu shortcuts and no entry in "Apps & Features."

**UPAI** makes portable apps feel "installed." It handles the Windows Uninstall registry integration, creates a standalone uninstaller, pins All-Users shortcuts, and optionally moves the application into the architecture-appropriate Program Files folder.

-----

## Editions

* **Pro Edition — Batch (`UPAI_v1.1.0.bat`):** Full-featured Batch installer with a skippable ASCII splash screen, CLI flags (`--silent`, `--exe`, `--move`, `--license`, `--help`), automatic PE architecture (`amd64`/`i386`/`arm64`) and version/publisher/size metadata detection, optional move to `Program Files` / `Program Files (x86)`, and duplicate install detection.
* **Pro Edition — PowerShell (`UPAI_v1.1.0.ps1`):** Native PowerShell counterpart to Batch Pro with full feature parity (`-Silent`, `-Exe`, `-MoveToProgramFiles`/`-Move`, `-License`, `-Help`) and clean, readable functions.
* **Lite Edition (`UPAI_Lite_v1.0.bat`):** Bare-bones, stripped-down Batch installer containing only the core prompts, hardened directory safety checks, uninstaller generator, registry integration, and shortcut creation.

-----

## Features

* **System Integration:** Adds your app to the Windows Uninstall list (`HKLM`) with icon, install location, size, version, and publisher metadata so it shows up cleanly in Windows Settings.
* **Architecture-Aware Move to Program Files (Pro):** Inspects the executable's PE header and optionally moves the app folder to `Program Files` (`amd64`/`arm64`) or `Program Files (x86)` (`i386`).
* **Automatic Uninstaller:** Creates a standalone `Uninstall_<App>.bat` (or `.ps1` in PowerShell Pro) that stops processes running from the app folder, removes registry keys and shortcuts, and deletes the application directory.
* **Shortcut Creation:** Pins All-Users shortcuts to **Desktop** and **Start Menu** automatically using .NET `[Environment]::GetFolderPath` (no VBScript).
* **Smart Detection:** Automatically selects a single `.exe` in a folder, provides an interactive menu when multiple `.exe` files exist, or accepts CLI flags in Pro Edition.
* **No-Nonsense Logic:** Uses native Batch and PowerShell so it runs out of the box on Windows 10 and 11.

-----

## Safety First

Because the uninstaller is designed to delete the application's folder when you're done with it, you need to be careful where you run this:

1. **Do not** run this script if the `.exe` is sitting directly on your Desktop, in Downloads, or in a system folder.
2. **Always** put your portable app in its own folder (e.g., `C:\Tools\MyLauncher`) before running UPAI (or let Pro move it into `Program Files`).
3. Both the installers and generated uninstallers include directory safety checks to block UNC paths, drive roots, Windows/system directories, `Program Files` roots, and user/OneDrive known folders, but common sense is still required.

-----

## How to Use

1. Move `UPAI_v1.1.0.bat`, `UPAI_v1.1.0.ps1`, or `UPAI_Lite_v1.0.bat` into the folder where your portable app lives.
2. Run it (it will automatically request **Administrator** privileges).
3. Follow the prompts to name the app, choose the main executable, and (in Pro) decide whether to move the folder to Program Files.

### Arguments — Batch Pro (`UPAI_v1.1.0.bat`)

* `--silent`: Installs without asking questions (requires App Name, and `--exe` if multiple executables exist).
* `--exe "app.exe"`: Tells the script exactly which executable inside the app folder to target.
* `--move`: Automatically moves the app folder to `Program Files` (`amd64`/`arm64`) or `Program Files (x86)` (`i386`).
* `--license`: Shows the GPL v3.0 notice (also supported in Lite Edition).
* `--help`, `-h`: Shows usage help.

### Parameters — PowerShell Pro (`UPAI_v1.1.0.ps1`)

Run with:
`powershell -NoProfile -ExecutionPolicy Bypass -File .\UPAI_v1.1.0.ps1 [options]`

* `-AppName "My App"` (or positional first argument): Application display name.
* `-Exe "app.exe"`: Target executable inside the app folder.
* `-MoveToProgramFiles` (alias `-Move`): Automatically moves the folder to `Program Files` or `Program Files (x86)`.
* `-Silent`: Non-interactive install.
* `-License`: Shows the GPL v3.0 notice.
* `-Help`: Shows usage help.

-----

## Development History

<<<<<<< HEAD
I wrote the core of this tool manually up to **Alpha-v0.6.3**. For **v1.0** and **v1.1.0**, I expanded and hardened the PowerShell functions, splash screen, architecture-aware Program Files relocation, safety checks, and native PowerShell Pro edition alongside the stripped-down **Lite Edition (`v1.0`)**.
=======
I wrote the core of this tool manually up to **Alpha-v0.6.3**. For the jump to **v1.0**, I used AI to help expand the PowerShell and VBScript functions.

While AI provided the "scaffolding," it introduced several logic errors (like registry hive mismatches and risky deletion paths). I have since gone through and fixed those bugs to ensure this version is rock-solid and safe enough for any Windows enthusiast to use daily.

I will soon add a Lite version that is just a skinned down version of the Normal/Pro one. (Lite is officially done, final reliability testing is being done)
>>>>>>> 8bcdce76da983e0320bd4862fe25ea3860209dd4
