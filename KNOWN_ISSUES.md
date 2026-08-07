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

As of image `2025.01` Surfer has been added. Surfer used to crash on various platforms due to issues with OpenGL drivers, most notably on macOS in X11 mode (`start_x.sh` with XQuartz), where it aborted with a `GLXBadFBConfig` panic.

Since image `2026.07` Surfer is started through a wrapper that forces the EGL rendering path (GLX is unusable against XQuartz) and, on TCP X connections, disables MIT-SHM presentation (SHM cannot be shared between the container and the host X server, which previously resulted in a blank window). With this wrapper, Surfer works in both VNC and X11 mode.

Note that in X11 mode Surfer is software-rendered inside the container and every frame is pushed uncompressed over the X connection, so the VNC mode feels snappier when working with Surfer. If Surfer still crashes on your platform, please file a bug report.

### Illegal Instruction (SIGILL) on Apple Silicon

On Apple Silicon the Linux VM that backs the container engine advertises the CPU
feature `SVE2` in `HWCAP2` while the base `SVE` bit in `HWCAP` stays clear — a
combination that cannot occur on real hardware, since SVE2 implies SVE. SVE
instructions then trap. The CPU probe of AWS-LC/OpenSSL trusts the SVE2 bit and
executes one (`cntb`, in `_armv8_sve_get_vl_bytes`) at library load time, so any
binary using that dispatch dies with `Illegal instruction (core dumped)`.

Observed on an Apple M4 with Podman 6.0.2 (Fedora CoreOS 41, kernel 6.12.13),
where it broke `import cryptography` (and therefore `siliconcompiler`) as well as
every `cocotb` simulation, which reports `Simulation failed: -4` because the
simulator embeds Python and loads the same extension. The same image and library
versions run fine on native `arm64` Linux, so this is a property of the VM, not
of the `arm64` image. It is not specific to Podman either: the incoherent feature
pair comes from the guest kernel on Apple's hypervisor, so Docker Desktop can be
affected in the same way, depending on the kernel its VM ships.

Since image `2026.08` the `start_*.sh` scripts detect Apple Silicon and pass
`OPENSSL_armcap=0` into the container, which makes the probe use that mask
instead of detecting capabilities and avoids the crash. The only cost is ARM
crypto acceleration inside the container. Export `OPENSSL_armcap` yourself to
pin a different mask, or export it empty to switch the workaround off.

### Podman Compatibility

The IIC-OSIC-TOOLS container can be run using Podman instead of Docker. The start scripts auto-detect the installed engine (override with `CONTAINER_ENGINE=podman`), and in rootless mode they automatically add `--userns=keep-id` and default the VNC webserver port to `8080`, see [Section 5.1 of the README](README.md#51-podman).

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
