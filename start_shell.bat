@echo off

:: ========================================================================
:: SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
:: Johannes Kepler University, Department for Integrated Circuits
::.
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::.
::     http://www.apache.org/licenses/LICENSE-2.0
::.
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.
:: SPDX-License-Identifier: Apache-2.0
:: ========================================================================

SETLOCAL

SET DEFAULT_DESIGNS=%USERPROFILE%\eda\designs

IF DEFINED DRY_RUN (
	echo This is a dry run, all commands will be printed to the shell ^(Commands printed but not executed are marked with ^$^)!
	SET ECHO_IF_DRY_RUN=ECHO $
)

IF "%DESIGNS%"=="" (
  SET DESIGNS=%DEFAULT_DESIGNS%
)
echo Using/creating designs directory: %DESIGNS%
if not exist "%DESIGNS%" %ECHO_IF_DRY_RUN% mkdir "%DESIGNS%"

:: Select the container engine (Docker or Podman), can be overridden by
:: setting CONTAINER_ENGINE.
IF NOT DEFINED CONTAINER_ENGINE (
  where /q docker
  IF NOT ERRORLEVEL 1 (
    SET CONTAINER_ENGINE=docker
  ) ELSE (
    where /q podman
    IF NOT ERRORLEVEL 1 (
      SET CONTAINER_ENGINE=podman
    ) ELSE (
      ECHO ERROR: No container engine found, please install Docker or Podman!
      EXIT /B 1
    )
  )
)
ECHO Using container engine %CONTAINER_ENGINE%

IF "%DOCKER_USER%"=="" SET DOCKER_USER=hpretl
IF "%DOCKER_IMAGE%"=="" SET DOCKER_IMAGE=iic-osic-tools
IF "%DOCKER_TAG%"=="" SET DOCKER_TAG=latest

:: Fully qualify the image name (Podman does not resolve short names
:: non-interactively).
IF "%DOCKER_REGISTRY%"=="" SET DOCKER_REGISTRY=docker.io
SET IMAGE_NAME=%DOCKER_REGISTRY%/%DOCKER_USER%/%DOCKER_IMAGE%:%DOCKER_TAG%

:: Docker Desktop and Podman machine expose the host WSLg directory at
:: different locations inside their WSL2 VMs.
SET WSLG_ROOT=/run/desktop/mnt/host/wslg
IF "%CONTAINER_ENGINE%"=="podman" SET WSLG_ROOT=/mnt/wslg

IF "%CONTAINER_USER%"=="" SET CONTAINER_USER=0
IF "%CONTAINER_GROUP%"=="" SET CONTAINER_GROUP=0

IF "%CONTAINER_NAME%"=="" SET CONTAINER_NAME=iic-osic-tools_shell

IF "%DISP%"=="" SET DISP=:0
IF "%WAYLAND_DISP%"=="" SET WAYLAND_DISP=wayland-0

IF %CONTAINER_USER% NEQ 0 if %CONTAINER_USER% LSS 1000 echo WARNING: Selected User ID %CONTAINER_USER% is below 1000. This ID might interfere with User-IDs inside the container and cause undefined behaviour!
IF %CONTAINER_GROUP% NEQ 0 if %CONTAINER_GROUP% LSS 1000 echo WARNING: Selected Group ID %CONTAINER_GROUP% is below 1000. This ID might interfere with Group-IDs inside the container and cause undefined behaviour!

SET PARAMS=--security-opt seccomp=unconfined

%CONTAINER_ENGINE% container inspect %CONTAINER_NAME% 2>&1 | find "Status" | find /i "running"
IF NOT ERRORLEVEL 1 (
    ECHO Container is running! Stop with \"%CONTAINER_ENGINE% stop %CONTAINER_NAME%\" and remove with \"%CONTAINER_ENGINE% rm %CONTAINER_NAME%\" if required.
) ELSE (
    %CONTAINER_ENGINE% container inspect %CONTAINER_NAME% 2>&1 | find "Status" | find /i "exited"
    IF NOT ERRORLEVEL 1 (
        echo Container %CONTAINER_NAME% exists. Restart with \"%CONTAINER_ENGINE% start %CONTAINER_NAME%\" or remove with \"%CONTAINER_ENGINE% rm %CONTAINER_NAME%\" if required.
    ) ELSE (
	echo Container does not exist, pulling %IMAGE_NAME% and creating %CONTAINER_NAME% ...
        %ECHO_IF_DRY_RUN% %CONTAINER_ENGINE% pull %IMAGE_NAME%
        %ECHO_IF_DRY_RUN% %CONTAINER_ENGINE% run -it --user %CONTAINER_USER%:%CONTAINER_GROUP% -e DISPLAY=%DISP% -e WAYLAND_DISPLAY=%WAYLAND_DISP% -e XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir -e PULSE_SERVER=/mnt/wslg/PulseServer -v %WSLG_ROOT%/.X11-unix:/tmp/.X11-unix -v %WSLG_ROOT%:/mnt/wslg --device=/dev/dxg -v /usr/lib/wsl:/usr/lib/wsl %DOCKER_EXTRA_PARAMS% %PARAMS% -v "%DESIGNS%":/foss/designs --name %CONTAINER_NAME% %IMAGE_NAME% -s /bin/bash
    )
)
