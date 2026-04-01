# Universal Portable App Installer (UPAI)

**Current Version:** 1.0 (Stable)  
**Author:** [danlogit/Kardani](https://github.com/danlogit)  
**License:** GNU GPL v3.0

-----

## What is this?

Portable apps are great because they don't clutter your system, but they usually lack basic Windows integration—no Start Menu shortcuts and no entry in "Apps & Features."

**UPAI** is a refined batch script that makes portable apps feel "installed." It handles the registry work and shortcut creation so your favorite tools are actually indexed by Windows, while keeping them completely portable.

-----

## Features

  * **System Integration:** Adds your app to the Windows Uninstall list (`HKLM`) so it shows up in system searches and settings.
  * **Automatic Uninstaller:** Creates a custom `Uninstall.bat` in the app folder that cleans up registry keys and shortcuts before removing the directory.
  * **Shortcut Creation:** Pins the app to your **Desktop** and **Start Menu** automatically.
  * **Smart Detection:** It can guess the right `.exe` in a folder or take specific instructions via command-line flags.
  * **No-Nonsense Logic:** Uses a mix of Batch, PowerShell (for file metadata), and VBScript (for shortcuts) to ensure it works even on locked-down systems.

-----

## Safety First

Because the uninstaller is designed to delete the application's folder when you're done with it, you need to be careful where you run this:

1.  **Do not** run this script if the `.exe` is sitting directly on your Desktop or in your Downloads folder.
2.  **Always** put your portable app in its own folder (e.g., `C:\Tools\MyLauncher`) before running UPAI.
3.  The script includes safety checks to prevent "nuking" important system folders, but common sense is still required.

-----

## How to Use

1.  Move `UPAI_v1.0.bat` into the folder where your portable app lives.
2.  Run it as **Administrator**.
3.  Follow the prompts to name the app and select the main executable.

### Arguments

  * `--silent`: Installs without asking questions (requires `--exe`).
  * `--exe "app.exe"`: Tells the script exactly which file to target.
  * `--license`: Shows the GPL v3.0 text.

-----

## Development History

I wrote the core of this tool manually up to **Alpha-v0.6.3**. For the jump to **v1.0**, I used AI to help expand the PowerShell and VBScript functions.

While AI provided the "scaffolding," it introduced several logic errors (like registry hive mismatches and risky deletion paths). I have since gone through and fixed those bugs to ensure this version is rock-solid and safe enough for any Windows enthusiast to use daily.

I will soon add a Lite version that is just a skinned down version of the Normal/Pro one. (Current development version: **Alpha-v0.1.4**)
