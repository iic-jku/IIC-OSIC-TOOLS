@echo off

:: ========================================================================
:: SPDX-FileCopyrightText: 2022-2025 Harald Pretl and Georg Zachl
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

IF "%DOCKER_USER%"=="" SET DOCKER_USER=hpretl
IF "%DOCKER_IMAGE%"=="" SET DOCKER_IMAGE=iic-osic-tools
IF "%DOCKER_TAG%"=="" SET DOCKER_TAG=chipathon

IF "%CONTAINER_USER%"=="" SET CONTAINER_USER=1000
IF "%CONTAINER_GROUP%"=="" SET CONTAINER_GROUP=1000

IF "%CONTAINER_NAME%"=="" SET CONTAINER_NAME=iic-osic-tools_chipathon_xserver

IF "%DISP%"=="" SET DISP=:0
IF "%WAYLAND_DISP%"=="" SET WAYLAND_DISP=wayland-0

IF "%JUPYTER_PORT%"=="" SET JUPYTER_PORT=8888

IF %CONTAINER_USER% NEQ 0 if %CONTAINER_USER% LSS 1000 echo WARNING: Selected User ID %CONTAINER_USER% is below 1000. This ID might interfere with User-IDs inside the container and cause undefined behaviour!
IF %CONTAINER_GROUP% NEQ 0 if %CONTAINER_GROUP% LSS 1000 echo WARNING: Selected Group ID %CONTAINER_GROUP% is below 1000. This ID might interfere with Group-IDs inside the container and cause undefined behaviour!

SET PARAMS=

IF %JUPYTER_PORT% GTR 0 (
  SET PARAMS=%PARAMS% -p %JUPYTER_PORT%:8888
)

IF DEFINED DOCKER_EXTRA_PARAMS (
  SET PARAMS=%PARAMS% %DOCKER_EXTRA_PARAMS%
)


docker container inspect %CONTAINER_NAME% 2>&1 | find "Status" | find /i "running"
IF NOT ERRORLEVEL 1 (
    ECHO Container is running! Stop with \"docker stop %CONTAINER_NAME%\" and remove with \"docker rm %CONTAINER_NAME%\" if required.
) ELSE (
    docker container inspect %CONTAINER_NAME% 2>&1 | find "Status" | find /i "exited"
    IF NOT ERRORLEVEL 1 (
        echo Container %CONTAINER_NAME% exists. Restart with \"docker start %CONTAINER_NAME%\" or remove with \"docker rm %CONTAINER_NAME%\" if required.
    ) ELSE (
	echo Container does not exist, pulling %DOCKER_USER%/%DOCKER_IMAGE%:%DOCKER_TAG% and creating %CONTAINER_NAME% ...
        %ECHO_IF_DRY_RUN% docker pull %DOCKER_USER%/%DOCKER_IMAGE%:%DOCKER_TAG%
        %ECHO_IF_DRY_RUN% docker run -d --user %CONTAINER_USER%:%CONTAINER_GROUP% -e DISPLAY=%DISP% -e WAYLAND_DISPLAY=%WAYLAND_DISP% -e XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir -e PULSE_SERVER=/mnt/wslg/PulseServer -v /run/desktop/mnt/host/wslg/.X11-unix:/tmp/.X11-unix -v /run/desktop/mnt/host/wslg:/mnt/wslg --device=/dev/dxg -v /usr/lib/wsl:/usr/lib/wsl %PARAMS% -v "%DESIGNS%":/foss/designs --name %CONTAINER_NAME% %DOCKER_USER%/%DOCKER_IMAGE%:%DOCKER_TAG%
    )
)
