@echo off
rem ===========================================================================
rem install.bat - Interactive installer for IIC-OSIC-TOOLS prerequisites
rem               (Windows 10 build 19044+ / Windows 11)
rem
rem Installs (each step asks for explicit confirmation):
rem   * winget self-check
rem   * Git for Windows                          (Git.Git)
rem   * WSL2 (kernel + default distribution)     (wsl --install)
rem   * Docker Desktop                           (Docker.DockerDesktop)
rem   * Clones the iic-osic-tools repository to a user-chosen directory
rem   * Reboots the machine (recommended after WSL / Docker install)
rem
rem Safety:
rem   * Uses winget exclusively (signed packages from Microsoft's repository);
rem     no curl-piped-to-shell, no manual MSI downloads.
rem   * Refuses to clone into obviously dangerous directories.
rem   * Idempotent: skips components that are already installed.
rem   * Every action is gated behind a [y/N] confirmation prompt.
rem ===========================================================================

setlocal EnableExtensions EnableDelayedExpansion

echo ============================================================
echo  IIC-OSIC-TOOLS interactive prerequisites installer (Windows)
echo ============================================================
echo.

rem --- Windows version sanity check ------------------------------------------
ver | findstr /R /C:"10\." /C:"11\." >nul
if errorlevel 1 (
    echo [WARN] This script is intended for Windows 10 / 11. Continuing anyway.
)

rem --- Detect winget ---------------------------------------------------------
where winget >nul 2>&1
if errorlevel 1 (
    echo [FAIL] 'winget' was not found on this system.
    echo        winget ships with the App Installer from the Microsoft Store.
    echo        Please install / update "App Installer" from the Microsoft Store
    echo        and run this script again.
    goto :fail
)
echo [ OK ] winget is available.
echo.

rem --- Top-level confirmation ------------------------------------------------
call :ask "This script will install required components interactively. Continue?"
if errorlevel 1 goto :aborted

rem --- Step 1: Git -----------------------------------------------------------
call :step "Install Git for Windows" install_git
if errorlevel 2 goto :fail

rem --- Step 2: WSL2 ----------------------------------------------------------
call :step "Install / enable WSL2 (required by Docker Desktop)" install_wsl
if errorlevel 2 goto :fail

rem --- Step 3: Docker Desktop ------------------------------------------------
call :step "Install Docker Desktop" install_docker
if errorlevel 2 goto :fail

rem --- Step 4: Clone repository ---------------------------------------------
call :step "Clone iic-osic-tools repository" clone_repo
if errorlevel 2 goto :fail

rem --- Show usage instructions before the (optional) reboot -----------------
call :show_usage_hints

rem --- Step 5: Reboot --------------------------------------------------------
call :step "Reboot Windows (recommended final step)" do_reboot
if errorlevel 2 goto :fail

echo.
echo [ OK ] All selected installation steps completed.
echo        If you did not reboot, please do so before launching Docker Desktop.
endlocal
exit /b 0

:aborted
echo [FAIL] Aborted by user.
endlocal
exit /b 1

:fail
echo [FAIL] Installation aborted due to an error.
endlocal
exit /b 1


rem ===========================================================================
rem Helper: ask "<prompt>"   -> sets ERRORLEVEL 0 (yes) or 1 (no)
rem ===========================================================================
:ask
set "_reply="
set /p "_reply=[?] %~1 [y/N]: "
if /I "!_reply!"=="y"   exit /b 0
if /I "!_reply!"=="yes" exit /b 0
exit /b 1


rem ===========================================================================
rem Helper: step "<title>" <label>
rem   Prints the step, asks for confirmation, calls :<label> if confirmed.
rem   Returns 2 on hard failure, 0 otherwise.
rem ===========================================================================
:step
echo.
echo [INFO] Step: %~1
call :ask "Proceed with this step?"
if errorlevel 1 (
    echo [WARN] Skipped: %~1
    exit /b 0
)
call :%~2
if errorlevel 1 exit /b 2
exit /b 0


rem ===========================================================================
rem Step implementations
rem ===========================================================================

:install_git
where git >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%v in ('git --version') do echo [ OK ] %%v already installed.
    exit /b 0
)
winget install --id Git.Git -e --source winget ^
    --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo [FAIL] Git installation failed.
    exit /b 1
)
echo [ OK ] Git installed.
exit /b 0


:install_wsl
rem A WSL kernel can be "installed" while no distribution is registered.
rem Both must be present, otherwise Docker Desktop will fail to start WSL2.
set "_wsl_ok=0"
wsl --status >nul 2>&1 && wsl --list --quiet >nul 2>&1 && set "_wsl_ok=1"
if "!_wsl_ok!"=="1" (
    echo [ OK ] WSL2 with at least one distribution appears to be installed.
    call :ask "Run 'wsl --update' to update the WSL kernel?"
    if not errorlevel 1 wsl --update
    exit /b 0
)
echo [INFO] Running 'wsl --install' (this will enable required Windows features
echo        and may take several minutes; a reboot is required afterwards).
wsl --install
if errorlevel 1 (
    echo [FAIL] 'wsl --install' failed. You typically need to run this script
    echo        from an *elevated* (Administrator) Command Prompt.
    exit /b 1
)
echo [ OK ] WSL2 installation initiated. A reboot is required to finish it.
exit /b 0


:install_docker
if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
    echo [ OK ] Docker Desktop already installed.
    exit /b 0
)
winget install --id Docker.DockerDesktop -e --source winget ^
    --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo [FAIL] Docker Desktop installation failed.
    exit /b 1
)
echo [ OK ] Docker Desktop installed. Launch it once from the Start menu
echo        after the reboot to finish setup.
exit /b 0


:clone_repo
set "_default=%USERPROFILE%\iic-osic-tools"
set "_target="
set /p "_target=[?] Directory to clone iic-osic-tools into [%_default%]: "
if not defined _target set "_target=%_default%"
if "!_target!"==""                       goto :clone_bad

rem --- Canonicalize: parent must exist; resolve to absolute path -----------
for %%P in ("!_target!\..") do set "_parent=%%~fP"
if not exist "!_parent!\" (
    echo [FAIL] Parent directory "!_parent!" does not exist. Create it first.
    exit /b 1
)
for %%F in ("!_target!") do set "_leaf=%%~nxF"
if not defined _leaf goto :clone_bad
set "_target=!_parent!\!_leaf!"

rem --- Reject obviously dangerous targets (after canonicalization) ---------
if /I "!_target!"=="%SystemDrive%\"       goto :clone_bad
if /I "!_target!"=="%SystemRoot%"         goto :clone_bad
if /I "!_target!"=="%ProgramFiles%"       goto :clone_bad
if /I "!_target!"=="%ProgramFiles(x86)%"  goto :clone_bad
if /I "!_target!"=="%USERPROFILE%"        goto :clone_bad
for %%D in ("%SystemRoot%\" "%ProgramFiles%\" "%ProgramFiles(x86)%\") do (
    echo !_target!\| findstr /I /B /C:"%%~D" >nul && goto :clone_bad
)

rem --- If target exists, only allow if it is already a git checkout --------
if exist "!_target!\.git" (
    echo [ OK ] Repository already present at "!_target!".
    call :ask "Run 'git pull' to update it?"
    if not errorlevel 1 (
        pushd "!_target!" >nul
        git pull --ff-only
        popd >nul
    )
    set "TARGET_DIR=!_target!"
    exit /b 0
)
if exist "!_target!" (
    echo [FAIL] "!_target!" exists and is not a git repository. Refusing to overwrite.
    exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
    echo [WARN] 'git' is not yet on PATH. If you just installed it, open a new
    echo        Command Prompt and re-run this step, or reboot first.
    exit /b 1
)

git clone --depth=1 https://github.com/iic-jku/iic-osic-tools.git "!_target!"
if errorlevel 1 (
    echo [FAIL] git clone failed.
    exit /b 1
)
echo [ OK ] Cloned iic-osic-tools to "!_target!".
set "TARGET_DIR=!_target!"
exit /b 0

:clone_bad
echo [FAIL] Refusing to clone into "!_target!".
exit /b 1


:do_reboot
echo [WARN] A reboot is strongly recommended to finalize WSL2 / Docker Desktop.
call :ask "Reboot now? (The system will restart in 60 seconds.)"
if errorlevel 1 (
    echo [WARN] Please reboot manually before using iic-osic-tools.
    exit /b 0
)
shutdown /r /t 60 /c "Rebooting to finalize IIC-OSIC-TOOLS prerequisites. Run 'shutdown /a' within 60s to abort."
echo [INFO] Reboot scheduled in 60 seconds. Run 'shutdown /a' to abort.
exit /b 0


rem ===========================================================================
rem Show usage instructions for the freshly installed iic-osic-tools.
rem ===========================================================================
:show_usage_hints
if not defined TARGET_DIR call :find_existing_repo
set "_repo=!TARGET_DIR!"
if not defined _repo set "_repo=<path-to-iic-osic-tools>"
echo.
echo ============================================================
echo  How to start IIC-OSIC-TOOLS
echo ============================================================
echo.
echo  1) Open a new Command Prompt and change into the repo dir:
echo        cd /d "!_repo!"
echo.
echo  2) Pick one of the launch modes (see README section 4):
echo.
echo        start_vnc.bat       Full XFCE desktop via browser
echo                            open http://localhost  (password: abc123)
echo.
echo        start_x.bat         Local X11 via WSLg (fast, integrated)
echo.
echo        start_jupyter.bat   Jupyter notebook server in the browser
echo.
echo        start_shell.bat     Shell-only access (advanced)
echo.
echo  3) Your design files live under %%DESIGNS%%
echo     (default: %%USERPROFILE%%\eda\designs) and are mounted
echo     into the container at /foss/designs.
echo.
echo  The first launch will pull the ~4 GB image from Docker Hub.
echo  Reserve at least 20 GB of free disk space.
echo ============================================================
echo.
exit /b 0


rem ===========================================================================
rem Try to locate an existing iic-osic-tools checkout if the clone step
rem was skipped. Sets TARGET_DIR on success.
rem ===========================================================================
:find_existing_repo
for %%C in ("%CD%" "%~dp0." "%USERPROFILE%\iic-osic-tools" "%USERPROFILE%\eda\iic-osic-tools") do (
    if exist "%%~fC\.git" (
        pushd "%%~fC" >nul
        for /f "delims=" %%U in ('git remote get-url origin 2^>nul') do (
            echo %%U | findstr /I "iic-osic-tools" >nul && set "TARGET_DIR=%%~fC"
        )
        popd >nul
        if defined TARGET_DIR exit /b 0
    )
)
exit /b 1
