@echo off

:: ========================================================================
:: Start script for ICD@JKU docker images (use for Jupyter notebooks only)
::
:: SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
:: Johannes Kepler University, Department for Integrated Circuits 
::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::     http://www.apache.org/licenses/LICENSE-2.0
::
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


IF NOT DEFINED DESIGNS SET DESIGNS=%DEFAULT_DESIGNS%
echo Using/creating designs directory: %DESIGNS%
if not exist "%DESIGNS%" %ECHO_IF_DRY_RUN% mkdir "%DESIGNS%" 

IF NOT DEFINED JUPYTER_PORT SET JUPYTER_PORT=8888

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

IF NOT DEFINED DOCKER_USER SET DOCKER_USER=hpretl
IF NOT DEFINED DOCKER_IMAGE SET DOCKER_IMAGE=iic-osic-tools
IF NOT DEFINED DOCKER_TAG SET DOCKER_TAG=latest

:: Fully qualify the image name (Podman does not resolve short names
:: non-interactively).
IF NOT DEFINED DOCKER_REGISTRY SET DOCKER_REGISTRY=docker.io
SET IMAGE_NAME=%DOCKER_REGISTRY%/%DOCKER_USER%/%DOCKER_IMAGE%:%DOCKER_TAG%

IF NOT DEFINED CONTAINER_USER SET CONTAINER_USER=1000
IF NOT DEFINED CONTAINER_GROUP SET CONTAINER_GROUP=1000

IF NOT DEFINED CONTAINER_NAME SET CONTAINER_NAME=iic-osic-tools_jupyter

IF %CONTAINER_USER% NEQ 0 if %CONTAINER_USER% LSS 1000 echo WARNING: Selected User ID %CONTAINER_USER% is below 1000. This ID might interfere with User-IDs inside the container and cause undefined behaviour!
IF %CONTAINER_GROUP% NEQ 0 if %CONTAINER_GROUP% LSS 1000 echo WARNING: Selected Group ID %CONTAINER_GROUP% is below 1000. This ID might interfere with Group-IDs inside the container and cause undefined behaviour!

SET PARAMS=--security-opt seccomp=unconfined
IF DEFINED JUPYTER_PORT SET PARAMS=%PARAMS% -p %JUPYTER_PORT%:8888
IF DEFINED DOCKER_EXTRA_PARAMS SET PARAMS=%PARAMS% %DOCKER_EXTRA_PARAMS%

@REM Check if the container exists and if it is running.
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
        %ECHO_IF_DRY_RUN% %CONTAINER_ENGINE% run -d --user %CONTAINER_USER%:%CONTAINER_GROUP% %PARAMS% -v "%DESIGNS%":/foss/designs --name %CONTAINER_NAME% %IMAGE_NAME% -s jupyter lab --no-browser
    )
)
