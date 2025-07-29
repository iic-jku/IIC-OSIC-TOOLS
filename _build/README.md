# IIC-OSIC-TOOLS (Build Instructions)

**ATTENTION:** Building such a large SW stack with many, *many* dependencies for multiple architectures is time-consuming and nerve wrecking! Please only attempt this with experience in Linux and SW builds (`./configure && make && make install` should not be a mystery, as a minimum).

## Details for Developers and Contributors

### Quick Start Instructions for Using new Build Setup

#### Step 1: Create builders

```bash
./builder-create.sh
```

If the username is different on the build machines from the local machine, or different build machines should be used, then a `BUILDER_STRS` can be supplied:

```bash
BUILDER_STRS="host=ssh://$USER@buildx86,host=ssh://$USER@buildaarch"
```

The builders use hostnames `buildx86` (for `x86_64`/`amd64` build) and `buildaarch` (for `aarch64`/`arm64` build), they need to be able to be reached by passwordless SSH.

To use a local image from a registry without https, the following entry has to be added to the Docker configuration file (e.g., `/etc/docker/daemon.json`):

```json
{
  "insecure-registries": ["registry.iic.jku.at:5000"]
}
```

#### Step 2: Build the `base` image

```bash
./build-base.sh
```

#### Step 3: Build the tools

```bash
./build-tools.sh
```

#### Step 4: Build the final image and push to Docker Hub

```bash
DOCKER_PREFIXES="hpretl,registry.iic.jku.at:5000" DOCKER_TAGS="latest" ./build-images.sh
```

To test locally-stored images, the following command cqn be used:

```bash
DOCKER_USER=registry.iic.jku.at:5000 DOCKER_TAG=next ./start_shell.sh
```

### Prerequisites

* [Docker](https://docs.docker.com/engine/install/)

### Building the container

The installation slightly differs from the original `foss-asic-tools` installation by efabless.com. For this image, the build is replaced with a single Dockerfile for convenience when doing a multi-architecture build. For a basic single (native)-architecture build, just run the following:

```bash
docker build .
```

You can add build parameters accordingly. We strongly recommend using `docker buildx` because of `buildkit` (parallel building) and multi-architecture support. The script `build_all.sh` includes building with `buildx`, on two different machines (for fast `amd64` and `arm64` builds) and pushes both images to the Docker Hub under the same tag. The script includes multiple environment variables with defaults. If you intend to build this image, we encourage you to use this script as a template.
The predefined settings are for the DIC build machines, and the image gets pushed with the tags `latest` and `year.month` (e.g., `2022.12`).

### Detailed container settings

For specific use cases, the containers can be started without the help of the start scripts. Here are a few things to note down:

#### Environment Variables

The container makes use of several environment variables to control the behavior. **WARNING:** those values maybe impact the functionality of the container. Do not change them unless you know what you are doing.

The internal VNC and webserver ports are defined by environment variables (not to be confused with the variables in the start script, those manage the external ports, to which the Docker daemon maps the ports! It works *best* if those are matched.). Those are used in the Dockerfile for the exposed ports and the configuration of the services.

* `VNC_PORT=5901` The default internal VNC port.
* `NO_VNC_PORT=80` The default internal webserver port.

Furthermore, the following variables can be set:

* `HOME=/headless` sets the home directory in the container.
* `TERM=xterm` is the default graphical terminal emulator.
* `STARTUPDIR=/dockerstartup` is the directory in which all container-related scripts are put.
* `NO_VNC_HOME=/dockerstartup/noVNC` is the directory for the noVNC installation.
* `VNC_COL_DEPTH=24` VNC color resolution.
* `VNC_RESOLUTION=1680x1050` VNC display resolution. NOTE: This can also be changed while running in the Desktop environment by going to Settings->Display.
* `VNC_PW=abc123` Default VNC password.
* `VNC_VIEW_ONLY=false` can set the VNC server to view only.
* `DESIGNS=/foss/designs` Default directory, where the user's designs are placed.
* `TOOLS=/foss/tools` Default tools directory.
* `PDK_ROOT=/foss/pdks` Default PDKs directory.

#### Entrypoint script

The entry point for this container is the [ui_startup.sh](https://github.com/hpretl/iic-osic-tools/blob/main/images/iic-osic-tools/scripts/ui_startup.sh) script. It controls which kind of UI (Xvnc or connecting to local X11 server) is used. The control logic for the automatic mode is simple. If the environment variable `DISPLAY` is set, an existing X11 server is assumed, and the startup script runs an XFCE4 terminal. If the `DISPLAY` is not set, it starts Xvnc and the noVNC web interface. This behavior can be overwritten with command-line arguments.

The following command line arguments are supported:

* `-X, --x11` Force to use local X11 forwarding requires a working combination of `$DISPLAY`, and either port forwards or mounted `XAUTHORITY` and `.X11_unix` socket.
* `-V, --vnc` Force use of VNC server, with noVNC and `websockify`.
* `-w, --wait` Runs the selected UI and waits for them to exit. The script will only return then. This flag is set in the container per default (via `CMD` in the Dockerfile).
* `-s, --skip` Skip the UI startup and execute the assigned command. **WARNING:** This must be the first parameter to the script, or it must be ignored! Example: `docker run hpretl/iic-osic-tools --skip bash`
* `-d, --debug` Enables more detailed startup output, e.g., `docker run hpretl/iic-osic-tools --debug`

As some examples already show, these parameters can be passed to the container via Docker:

```bash
docker run -it hpretl/iic-osic-tools:latest --wait --vnc
```

## Notes

* Each tool has a separate directory in the `images` directory with the build script and additional required files.
* The tool versions (typically the commit hash) have defaulted in the Dockerfile. It can be overwritten via environment variables.
* Only the final image is tagged; the sub-tools are not. It is still possible to build only to a certain stage (stages are defined in the Dockerfile by `FROM base_image as stage_name`).
* The final image is called `iic-osic-tool` by default.
* Docker on Windows suffers from bad memory management due to WSL2, especially for systems with less than 16GB RAM. As a workaround, a memory limit to WSL can be set. See [Advanced settings configuration in WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) (look for the key "memory" in the `wsl2` tag).

## Todo

n/a
