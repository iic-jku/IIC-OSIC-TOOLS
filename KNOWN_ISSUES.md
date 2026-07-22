# IIC-OSIC-TOOLS Known Issues

## Container

### Using the X11-mode on Linux with Docker Desktop

Due to the quite different way of how Docker Desktop works to the classical Docker CE, `socat` is required to forward the X11 sockets to the container.
To install `socat`, here are the commands for popular distributions:

- Ubuntu/Debian (deb-based): `sudo apt-get -y install socat`
- Arch/Manjaro (pacman-based): `pacman -S socat`
- Fedora/RHEL/Rocky/Alma (rpm-based, RHEL-clones): `dnf -y install socat`
- SuSE/openSUSE (rpm-based, SuSE-clones): `zypper install socat`

### Switching to WSLg for Graphical Applications on Windows

The current variant of the `start_x.bat` for Windows uses WSLg for audio & visual output, which comes preinstalled/packaged with WSL (Windows 10 Build 19044 or Windows 11). If problems arise, update WSL according to [the Microsoft website](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps).

### Frequent Crashes of `xschem` on Windows 10+

Since the update of the image to Ubuntu 24.04 LTS with tag `2025.01` there are reports of frequent crashes of `xschem` under Windows 11 using certain versions of specific X-servers. It has been found that using <https://vcxsrv.com> version `64.1.17.2.0` under Windows 11 works well (see [issue 92](https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/92)).

### Issues with OpenGL on Some Environments

A few applications are using OpenGL graphics, which can lead to issues on some computing environments. A (potential) remedy is to enable SW-rendering with can be achieved by setting the following environment variable inside the Docker VM:

```bash
export LIBGL_ALWAYS_INDIRECT=0
```

### Issues with KLayout PCell Libraries

Some pcell libraries were developed for older `gdsfactory` versions:

- Skywater `sky130A`/`sky130B`: pcells were written against the `gdsfactory` 8.x APIs and private kfactory 0.17.x internals (`_get_default_kcl`, `_kdb_cell`, `Component.add_array`, implicit generic-PDK activation), which later `gdsfactory`/kfactory versions removed.
- Global Foundries `gf180mcuC`/`gf180mcuD`: pcells rely on the implicit generic-PDK activation that `gdsfactory` removed in 9.29.0.

The image addresses these automatically (issue <https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/162>): both pcell libraries are patched at PDK-install time so they work with the current system `gdsfactory` and need no dedicated virtual environment.

### The OpenROAD Flow Scripts (ORFS)

The ORFS require a recent version of `openroad`. Since image tag `2024.12` a recent version is installed alongside the OpenROAD version required by `librelane`. In tag `2025.10` and beyond the `openroad` and `sta` version that is found is a recent version that can be used with the ORFS.In order to use the ORFS, **before** calling the `make` script make sure to set the following env vars:

```bash
export YOSYS_EXE=$TOOLS/yosys/bin/yosys
export OPENROAD_EXE=$TOOLS/openroad/bin/openroad
export OPENSTA_EXE=$TOOLS/openroad/bin/sta
```

Since the OpenROAD and ORFS version are tightly interlinked with regular interface breaks, the ORFS Git commit hash at image build time is stored in `$TOOLS/openroad/ORFS_COMMIT`. After cloning ORFS from GitHub use the following command to switch to a working and tested ORFS version:

```bash
git checkout $(cat $TOOLS/openroad/ORFS_COMMIT)
```

### Surfer Crashing

As of image `2025.01` Surfer has been added. Surfer is known to crash on quite a few platforms due to issues with OpenGL drivers. If Surfer works on your platform, great. If Surfer does crash then this is not good, but there is currently no solution available. Please do not file bug reports. As soon as we are aware of a solution for these crashes we will implement the fixes.

### Podman Compatibility

The IIC-OSIC-Tools container can be run using Podman instead of Docker. The start scripts auto-detect the installed engine (override with `CONTAINER_ENGINE=podman`), and in rootless mode they automatically add `--userns=keep-id` and default the VNC webserver port to `8080`, see [Section 5.1 of the README](README.md#51-podman).

If you run *rootful* Podman with a non-root `CONTAINER_USER`, bind-mounts are mounted as root, which creates problems when accessing files inside the container. In this case, either switch to rootless Podman (recommended), or edit the desired start script and find/replace all occurrences of `:rw` with `:U,rw`, so Podman will chown the mounted directories to the given `UID` inside the container.

### Docker Rootless Mode

Running Docker in rootless mode with X11/Wayland forwarding (`start_x.sh`) is not fully supported. The X11 and Wayland sockets are not accessible from the container due to UID/GID mismatches in the user namespace. There is no straightforward fix for Docker rootless mode.

**Workaround:** Switch to [Podman](https://podman.io/) in rootless mode (see [Section 5.1 of the README](README.md#51-podman)). The start scripts automatically detect Podman rootless mode and add `--userns=keep-id`.

### Palace EM-Setup

Volker Muehlaus' `setupEM`/`gds2palace` tool for AWS Palace is only installed for `x86_64`, as there are currently issues with `gmsh` for `arm64` on Linux.

### GDS3D crashing on macOS

At least since tag `2025.12` GDS3D is crashing with an error message. Unfortunately, there is no known fix at the moment. See <https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/220>.

## Build

No known issues at the moment. However, be warned that building the image is quite involved and may take several hours depending on the host system performance and network connection. For a multi-architecture build (`amd64` + `arm64`) dedicated build servers with sufficient resources are recommended. Cross-architecture builds take ages and are not recommended. Plus, a private Docker registry is currently used by the build system to store intermediate build stages, which requires a fast network connection to the registry server.
