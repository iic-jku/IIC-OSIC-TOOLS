# IIC-OSIC-TOOLS Known Issues

## Container

### Starting the Container

If you run into problems when starting the container (mostly in combination with SELinux), try to run the container with the following environment variable set to `DOCKER_EXTRA_PARAMS='--security-opt seccomp=unconfined'`. This will overwrite the Docker Default security settings so use with it care!

Example:

```DOCKER_EXTRA_PARAMS='--security-opt seccomp=unconfined' ./start_x.sh```

### Issues with OpenGL on some environments

A few applications are using OpenGL graphics, which can lead to issues on some computing environments. A (potential) remedy is to enable SW-rendering with can be achieved by setting the following environment variable inside the Docker VM:

`LIBGL_ALWAYS_INDIRECT=0`

### OpenEMS

The visualization tool "AppCSXCAD" will not work in the container with our default settings (`vtkXOpenGLRenderWindow (0x....): Cannot create GLX context.  Aborting.`). The issue has been located to be connected with the environment variable "LIBGL_ALWAYS_INDIRECT". As a workaround, we suggest either unsetting the variable or setting it to 0 (`unset LIBGL_ALWAYS_INDIRECT` or `export LIBGL_ALWAYS_INDIRECT=0`) which is persistent for the running terminal or run AppCSXCAD with the variable set to zero inline: `LIBGL_ALWAYS_INDIRECT=0 AppCSXCAD`.

### Hdl21/Vlsirtools

We (temporarily) removed `Hdl21` and `Vlsirtools`, as they force `numpy` to version 1. All other packages allow `numpy` 2, so this removal, until the dependencies are fixed.

### Scikit-RF on `aarch64`

Importing `skrf` in Python throws an error due to `bottleneck`; this does not happen on `amd64`.

## Build

### Boost

Boost is currently installed from the package sources of Ubuntu and a manual install/build. This is currently required, as there are some dependencies from packages, but also, some manually built tools require a newer boost version. This issue will be resolved in the future when switching to a more modern Ubuntu release.
