# IIC-OSIC-TOOLS Known Issues

## Container

### Starting the Container

If you run into problems when starting the container (mostly in combination with SELinux), try to run the container with the following environment variable set to `DOCKER_EXTRA_PARAMS='--security-opt seccomp=unconfined'`. This will overwrite the Docker Default security settings so use with it care!

Example:

```bash
DOCKER_EXTRA_PARAMS='--security-opt seccomp=unconfined' ./start_x.sh
```

### Frequent crashes of `xschem` on Windows 11

Since the update of the image to Ubuntu 24.04 LTS with tag `2025.01` there are reports of frequent crashes of `xschem` under Windows 11 using certain versions of specific X-servers. It has been found that using <https://vcxsrv.com> version `64.1.17.2.0` under Windows 11 works well (see [issue 92](https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/92)).

### Issues with OpenGL on some environments

A few applications are using OpenGL graphics, which can lead to issues on some computing environments. A (potential) remedy is to enable SW-rendering with can be achieved by setting the following environment variable inside the Docker VM:

`LIBGL_ALWAYS_INDIRECT=0`

### The OpenROAD Flow Scripts (ORFS)

The ORFS required a recent version of `openroad`. Since image tag `2024.12` a recent version is installed alongside the OpenROAD version required by `openlane`. In order to use the ORFS, before calling the `make` script make sure to set the following env vars:

```bash
export YOSYS_EXE=$TOOLS/yosys/bin/yosys
export OPENROAD_EXE=$TOOLS/openroad-latest/bin/openroad
export OPENSTA_EXE=$TOOLS/openroad-latest/bin/sta
```

### Surfer crashing

As of image `2025.01` Surfer has been added. Surfer is known to crash on quite a few platforms due to issues with OpenGL drivers. If Surfer works on your platform, great. If Surfer does crash then this is not good, but there is currently no solution available. Please do not file bug reports. As soon as we are aware of a solution for these crashes we will implement the fixes.

### OpenEMS

The visualization tool "AppCSXCAD" will not work in the container with our default settings (`vtkXOpenGLRenderWindow (0x....): Cannot create GLX context.  Aborting.`). The issue has been located to be connected with the environment variable "LIBGL_ALWAYS_INDIRECT". As a workaround, we suggest either unsetting the variable or setting it to 0 (`unset LIBGL_ALWAYS_INDIRECT` or `export LIBGL_ALWAYS_INDIRECT=0`) which is persistent for the running terminal or run AppCSXCAD with the variable set to zero inline: `LIBGL_ALWAYS_INDIRECT=0 AppCSXCAD`.

### PyOPUS

`PyOPUS` is removed, as build fails, and it forces `numpy` to version 1.

## Build
