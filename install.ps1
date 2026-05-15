# ========================================================================
# install.ps1 - Interactive installer for IIC-OSIC-TOOLS prerequisites
#               (Windows 10 build 19044+ / Windows 11)
#
# SPDX-FileCopyrightText: 2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
# ========================================================================
#
# Designed to be runnable BOTH as a local file
#
#     powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# and as a one-liner that downloads-and-executes:
#
#     powershell -c "irm https://osic.tools/install.ps1 | iex"
#
# Installs (each step asks for explicit confirmation):
#   * winget self-check
#   * Git for Windows                          (Git.Git)
#   * WSL2 (kernel + default distribution)     (wsl --install)
#   * Docker Desktop                           (Docker.DockerDesktop)
#   * Clones the iic-osic-tools repository to a user-chosen directory
#   * Reboots the machine (recommended after WSL / Docker install)
#
# Safety:
#   * Uses winget exclusively (signed packages from Microsoft's repository);
#     no curl-piped-to-shell, no manual MSI downloads.
#   * Refuses to clone into obviously dangerous directories.
#   * Idempotent: skips components that are already installed.
#   * Every action is gated behind a [y/N] confirmation prompt.
# ========================================================================

# Stop on uncaught errors, but allow controlled handling within helpers.
$ErrorActionPreference = 'Stop'

# --- pretty printing -----------------------------------------------------
function Write-Info([string]$Msg) { Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Ok  ([string]$Msg) { Write-Host "[ OK ] $Msg" -ForegroundColor Green }
function Write-Warn2([string]$Msg) { Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Fail([string]$Msg) { Write-Host "[FAIL] $Msg" -ForegroundColor Red }

# --- piped-from-irm support ----------------------------------------------
# When invoked via `irm ... | iex`, $PSCommandPath / $MyInvocation.MyCommand.Path
# are empty. Read-Host still works because PowerShell talks to the host,
# not to stdin, so no special handling is required here -- we only need
# to make sure we never assume a script-on-disk location.
$script:TargetDir = $null

# --- helpers --------------------------------------------------------------
function Ask([string]$Prompt) {
    while ($true) {
        $reply = Read-Host -Prompt "[?] $Prompt [y/N]"
        switch -Regex ($reply) {
            '^(?i:y|yes)$' { return $true }
            '^(?i:n|no|)$' { return $false }
            default        { Write-Host 'Please answer yes or no.' }
        }
    }
}

function Step([string]$Title, [scriptblock]$Action) {
    Write-Host ''
    Write-Info "Step: $Title"
    if (-not (Ask 'Proceed with this step?')) {
        Write-Warn2 "Skipped: $Title"
        return
    }
    try {
        & $Action
    } catch {
        Write-Fail "Step '$Title' failed: $($_.Exception.Message)"
        throw
    }
}

function Test-Command([string]$Name) {
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Invoke-Winget {
    param([Parameter(Mandatory)] [string[]] $WingetArgs)
    & winget @WingetArgs
    if ($LASTEXITCODE -ne 0) {
        throw "winget exited with code $LASTEXITCODE."
    }
}

# --- disclaimer -----------------------------------------------------------
function Show-Disclaimer {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Yellow
    Write-Host '                       !!! NOTICE !!!'                         -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'This installer will make changes to your system (installing'
    Write-Host 'software via winget, enabling Windows features, registering'
    Write-Host 'WSL2 distributions, installing Docker Desktop, and optionally'
    Write-Host 'rebooting the machine).'
    Write-Host ''
    Write-Host 'USE AT YOUR OWN RISK. The authors and contributors of'         -ForegroundColor Yellow
    Write-Host 'IIC-OSIC-TOOLS provide this script "AS IS", WITHOUT WARRANTY'
    Write-Host 'OF ANY KIND, express or implied. In no event shall the authors'
    Write-Host 'be liable for any claim, damages, data loss, system corruption,'
    Write-Host 'or other liability arising from the use of this script.'
    Write-Host ''
    Write-Host 'It is strongly recommended to:'
    Write-Host '  * back up important data BEFORE proceeding,'
    Write-Host '  * review the script before running it,'
    Write-Host '  * run it on a freshly installed or test system when possible.'
    Write-Host ''
    Write-Host 'Every individual step will still prompt for confirmation.'
    Write-Host '============================================================' -ForegroundColor Yellow
    Write-Host ''
    if (-not (Ask 'I have read the notice above and accept full responsibility. Continue?')) {
        throw 'Aborted by user at disclaimer prompt.'
    }
}

# --- step implementations -------------------------------------------------
function Install-Git {
    if (Test-Command git) {
        Write-Ok "$(git --version) already installed."
        return
    }
    Invoke-Winget @('install','--id','Git.Git','-e','--source','winget',
                    '--accept-package-agreements','--accept-source-agreements')
    Write-Ok 'Git installed.'
}

function Install-Wsl {
    # A WSL kernel can be "installed" while no distribution is registered.
    # Both must be present, otherwise Docker Desktop will fail to start WSL2.
    $wslOk = $false
    try {
        & wsl --status   *> $null
        $statusOk = ($LASTEXITCODE -eq 0)
        & wsl --list --quiet *> $null
        $listOk   = ($LASTEXITCODE -eq 0)
        $wslOk    = ($statusOk -and $listOk)
    } catch { $wslOk = $false }

    if ($wslOk) {
        Write-Ok 'WSL2 with at least one distribution appears to be installed.'
        if (Ask "Run 'wsl --update' to update the WSL kernel?") {
            & wsl --update
        }
        return
    }
    Write-Info "Running 'wsl --install' (enables Windows features; reboot required afterwards)."
    & wsl --install
    if ($LASTEXITCODE -ne 0) {
        throw "'wsl --install' failed. Re-run this script from an *elevated* (Administrator) PowerShell."
    }
    Write-Ok 'WSL2 installation initiated. A reboot is required to finish it.'
}

function Install-DockerDesktop {
    $dockerExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    if (Test-Path -LiteralPath $dockerExe) {
        Write-Ok 'Docker Desktop already installed.'
        return
    }
    Invoke-Winget @('install','--id','Docker.DockerDesktop','-e','--source','winget',
                    '--accept-package-agreements','--accept-source-agreements')
    Write-Ok 'Docker Desktop installed. Launch it once from the Start menu after the reboot.'
}

function Clone-Repo {
    $default = Join-Path $env:USERPROFILE 'iic-osic-tools'
    $entered = Read-Host -Prompt "[?] Directory to clone iic-osic-tools into [$default]"
    if ([string]::IsNullOrWhiteSpace($entered)) { $entered = $default }

    # Resolve parent to absolute path before validating, to prevent traversal
    # tricks like '..' from bypassing the dangerous-paths blocklist.
    $parent = Split-Path -Path $entered -Parent
    if ([string]::IsNullOrWhiteSpace($parent)) {
        throw "Cannot determine parent directory of '$entered'."
    }
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Parent directory '$parent' does not exist. Create it first."
    }
    $parentAbs = (Resolve-Path -LiteralPath $parent).ProviderPath
    $leaf = Split-Path -Path $entered -Leaf
    if ([string]::IsNullOrWhiteSpace($leaf)) {
        throw "Refusing to clone into a directory with an empty name."
    }
    $target = Join-Path $parentAbs $leaf

    # Reject obviously dangerous targets (after canonicalization).
    $forbidden = @(
        [System.IO.Path]::GetPathRoot($env:SystemRoot),
        $env:SystemRoot,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:USERPROFILE
    ) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }

    $targetTrim = $target.TrimEnd('\')
    foreach ($f in $forbidden) {
        if ([string]::Equals($targetTrim, $f, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clone into '$target'."
        }
    }
    foreach ($f in @($env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }) {
        $fPrefix = $f.TrimEnd('\') + '\'
        if ($targetTrim.StartsWith($fPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clone into '$target'."
        }
    }

    if (Test-Path -LiteralPath (Join-Path $target '.git')) {
        Write-Ok "Repository already present at '$target'."
        if (Ask "Run 'git pull' to update it?") {
            Push-Location -LiteralPath $target
            try { & git pull --ff-only } finally { Pop-Location }
        }
        $script:TargetDir = $target
        return
    }
    if (Test-Path -LiteralPath $target) {
        throw "'$target' exists and is not a git repository. Refusing to overwrite."
    }

    if (-not (Test-Command git)) {
        throw "'git' is not yet on PATH. If you just installed it, open a new PowerShell and re-run this step, or reboot first."
    }

    & git clone --depth=1 https://github.com/iic-jku/iic-osic-tools.git $target
    if ($LASTEXITCODE -ne 0) {
        throw 'git clone failed.'
    }
    Write-Ok "Cloned iic-osic-tools to '$target'."
    $script:TargetDir = $target
}

function Find-ExistingRepo {
    $candidates = @(
        (Get-Location).Path,
        (Join-Path $env:USERPROFILE 'iic-osic-tools'),
        (Join-Path $env:USERPROFILE 'eda\iic-osic-tools')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ '.git')) }
    foreach ($c in $candidates) {
        Push-Location -LiteralPath $c
        try {
            $url = & git remote get-url origin 2>$null
            if ($LASTEXITCODE -eq 0 -and $url -match 'iic-osic-tools') {
                return (Resolve-Path -LiteralPath $c).ProviderPath
            }
        } finally { Pop-Location }
    }
    return $null
}

function Show-UsageHints {
    if (-not $script:TargetDir) { $script:TargetDir = Find-ExistingRepo }
    $repo = if ($script:TargetDir) { $script:TargetDir } else { '<path-to-iic-osic-tools>' }
    Write-Host ''
    Write-Host '============================================================'
    Write-Host ' How to start IIC-OSIC-TOOLS'
    Write-Host '============================================================'
    Write-Host ''
    Write-Host " 1) Open a new PowerShell and change into the repo dir:"
    Write-Host "      cd `"$repo`""
    Write-Host ''
    Write-Host ' 2) Pick one of the launch modes (see README section 4):'
    Write-Host ''
    Write-Host '      .\start_vnc.bat       Full XFCE desktop via browser'
    Write-Host '                            open http://localhost  (password: abc123)'
    Write-Host ''
    Write-Host '      .\start_x.bat         Local X11 via WSLg (fast, integrated)'
    Write-Host ''
    Write-Host '      .\start_jupyter.bat   Jupyter notebook server in the browser'
    Write-Host ''
    Write-Host '      .\start_shell.bat     Shell-only access (advanced)'
    Write-Host ''
    Write-Host ' 3) Your design files live under $env:DESIGNS'
    Write-Host '    (default: $env:USERPROFILE\eda\designs) and are mounted'
    Write-Host '    into the container at /foss/designs.'
    Write-Host ''
    Write-Host ' The first launch will pull the ~4 GB image from Docker Hub.'
    Write-Host ' Reserve at least 20 GB of free disk space.'
    Write-Host '============================================================'
    Write-Host ''
}

function Invoke-Reboot {
    Write-Warn2 'A reboot is strongly recommended to finalize WSL2 / Docker Desktop.'
    if (-not (Ask 'Reboot now? (The system will restart in 60 seconds.)')) {
        Write-Warn2 'Please reboot manually before using iic-osic-tools.'
        return
    }
    & shutdown /r /t 60 /c 'Rebooting to finalize IIC-OSIC-TOOLS prerequisites. Run ''shutdown /a'' within 60s to abort.'
    Write-Info "Reboot scheduled in 60 seconds. Run 'shutdown /a' to abort."
}

# --- main ----------------------------------------------------------------
function Main {
    Write-Host '============================================================'
    Write-Host ' IIC-OSIC-TOOLS interactive prerequisites installer (Windows)'
    Write-Host '============================================================'
    Write-Host ''

    Show-Disclaimer

    # Windows version sanity check
    $os = [System.Environment]::OSVersion.Version
    if ($os.Major -lt 10) {
        Write-Warn2 'This script is intended for Windows 10 / 11. Continuing anyway.'
    }

    if (-not (Test-Command winget)) {
        Write-Fail "'winget' was not found on this system."
        Write-Host "       winget ships with the App Installer from the Microsoft Store."
        Write-Host '       Please install / update "App Installer" from the Microsoft Store'
        Write-Host '       and run this script again.'
        throw 'winget missing.'
    }
    Write-Ok 'winget is available.'
    Write-Host ''

    if (-not (Ask 'This script will install required components interactively. Continue?')) {
        throw 'Aborted by user.'
    }

    Step 'Install Git for Windows'                          { Install-Git }
    Step 'Install / enable WSL2 (required by Docker Desktop)' { Install-Wsl }
    Step 'Install Docker Desktop'                           { Install-DockerDesktop }
    Step 'Clone iic-osic-tools repository'                  { Clone-Repo }

    Show-UsageHints

    Step 'Reboot Windows (recommended final step)'          { Invoke-Reboot }

    Write-Host ''
    Write-Ok 'All selected installation steps completed.'
    Write-Host '       If you did not reboot, please do so before launching Docker Desktop.'
}

try {
    Main
    exit 0
} catch {
    Write-Fail $_.Exception.Message
    exit 1
}
