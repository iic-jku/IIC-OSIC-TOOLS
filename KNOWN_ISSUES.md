# IIC-OSIC-TOOLS Known Issues

## Container

### Starting the container

If you run into problems when starting the container (mostly in combination with SELinux), try to run the container with the following environment variable set to `DOCKER_EXTRA_PARAMS='--security-opt seccomp=unconfined'`. This will overwrite the Docker default security settings so use with it care!

Example:

```bash
DOCKER_EXTRA_PARAMS='--security-opt seccomp=unconfined' ./start_x.sh
```

### Switching to WSLg for graphical applications on Windows

The current variant of the `start_x.bat` for Windows uses WSLg for audio & visual output, which comes preinstalled/packaged with WSL (Windows 10 Build 19044 or Windows 11). If problems arise, update WSL according to [the Microsoft website](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps).

### Frequent crashes of `xschem` on Windows 10+

Since the update of the image to Ubuntu 24.04 LTS with tag `2025.01` there are reports of frequent crashes of `xschem` under Windows 11 using certain versions of specific X-servers. It has been found that using <https://vcxsrv.com> version `64.1.17.2.0` under Windows 11 works well (see [issue 92](https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/92)).

### Issues with OpenGL on some environments

A few applications are using OpenGL graphics, which can lead to issues on some computing environments. A (potential) remedy is to enable SW-rendering with can be achieved by setting the following environment variable inside the Docker VM:

```bash
export LIBGL_ALWAYS_INDIRECT=0
```

### The OpenROAD Flow Scripts (ORFS)

The ORFS require a recent version of `openroad`. Since image tag `2024.12` a recent version is installed alongside the OpenROAD version required by `openlane`. In order to use the ORFS, **before** calling the `make` script make sure to set the following env vars:

```bash
export YOSYS_EXE=$TOOLS/yosys/bin/yosys
export OPENROAD_EXE=$TOOLS/openroad-latest/bin/openroad
export OPENSTA_EXE=$TOOLS/openroad-latest/bin/sta
```

Since the OpenROAD and ORFS version are tightly interlinked with regular interface breaks, the ORFS Git commit hash at image build time is stored in `$TOOLS/openroad-latest/ORFS_COMMIT`. After cloning ORFS from GitHub use the following command to switch to a working and tested ORFS version:

```bash
git checkout $(cat $TOOLS/openroad-latest/ORFS_COMMIT)
```

### Surfer crashing

As of image `2025.01` Surfer has been added. Surfer is known to crash on quite a few platforms due to issues with OpenGL drivers. If Surfer works on your platform, great. If Surfer does crash then this is not good, but there is currently no solution available. Please do not file bug reports. As soon as we are aware of a solution for these crashes we will implement the fixes.

### OpenEMS (currently removed from the image)

The visualization tool "AppCSXCAD" will not work in the container with our default settings (`vtkXOpenGLRenderWindow (0x....): Cannot create GLX context.  Aborting.`). The issue has been located to be connected with the environment variable "LIBGL_ALWAYS_INDIRECT". As a workaround, we suggest either unsetting the variable or setting it to 0 (`unset LIBGL_ALWAYS_INDIRECT` or `export LIBGL_ALWAYS_INDIRECT=0`) which is persistent for the running terminal or run AppCSXCAD with the variable set to zero inline: `LIBGL_ALWAYS_INDIRECT=0 AppCSXCAD`.

### PyOPUS

`PyOPUS` is removed, as build fails, and it forces `numpy` to version 1.

### Podman compatibility

The IIC-OSIC-Tools container can be run using Podman instead of Docker (with the Podman Docker compatible CLI), but it introduces some problems:

- By default, Podman mounts all bind-mounts/volumes as root, even though the `UID` inside the container is != 0, which creates some problems when accessing files inside the container. To work around this issue, we suggest the following procedure:
- Edit the desired start script and find/replace all occurrences of `:rw` with `:U,rw`. Then Podman will mount all listed directories with the given `UID` inside the container.

## Build

No kown issues at the moment.
