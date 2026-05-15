@echo off
:: ========================================================================
:: install.bat - Thin shim that launches install.ps1 in PowerShell.
::
:: Exists so that users who double-click the file in Explorer (where .ps1
:: files open in Notepad by default) still get an interactive installer.
:: All real logic lives in install.ps1 -- please edit that file, not this
:: one.
::
:: SPDX-FileCopyrightText: 2026 Harald Pretl and Georg Zachl
:: Johannes Kepler University, Department for Integrated Circuits
:: SPDX-License-Identifier: Apache-2.0
:: ========================================================================

setlocal

if not exist "%~dp0install.ps1" (
    echo [FAIL] install.ps1 not found next to install.bat ^(expected at "%~dp0install.ps1"^).
    echo        Please re-download the iic-osic-tools repository.
    endlocal
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "_rc=%ERRORLEVEL%"

:: When launched via double-click the console window closes immediately on
:: exit. Pause so the user can see the result. Skip the pause if invoked
:: from an existing interactive shell (cmd /K) or with arguments.
echo %CMDCMDLINE% | findstr /I /C:"/c" >nul && pause

endlocal & exit /b %_rc%
