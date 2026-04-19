# IIC-OSIC-TOOLS Known Issues

## Container

### Using the X11-mode on Linux with Docker Desktop

Due to the quite different way of how Docker Desktop works to the classical Docker CE, `socat` is required to forward the X11 sockets to the container.
To install `socat`, here are the commands for popular distributions:

- Ubuntu/Debian (deb-based): `sudo apt-get -y install socat`
- Arch/Manjaro (pacman-based): `pacman -S socat`
- Fedora/RHEL/Rocky/Alma (rpm-based, RHEL-clones): `dnf -y install socat`
- SuSE/openSUSE (rpm-based, SuSE-clones): `zypper install socat`

### X11 Authorization Failure When Xauthority Path Is a Directory (Wayland/Linux)

When running `start_x.sh` on Linux with a Wayland compositor (e.g., KDE Plasma/KWin), the script creates a temporary Xauthority file at `/tmp/.iic-osic-tools_xserver_uid_<UID>_xauthority`. If a **directory** with that name already exists (e.g., left behind by a previous failed run), the script fails with:

```text
./start_x.sh: line 185: /tmp/.iic-osic-tools_xserver_uid_1000_xauthority: Is a directory
xauth:  /tmp/.iic-osic-tools_xserver_uid_1000_xauthority not writable, changes will be ignored
```

As a result, all GUI applications inside the container (e.g., `xschem`, `klayout`) fail with `Authorization required, but no authorization protocol specified` and do not open their graphical interface.

#### Workaround

Remove the stale directory before running `start_x.sh`:

```bash
rm -rf /tmp/.iic-osic-tools_xserver_uid_$(id -u)_xauthority
```

Then re-run `start_x.sh` (removing the existing container with `r` if prompted).

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

- Skywater `sky130A`/`sky130B`: pcells require `gdsfactory==8.0.0` (the version that introduced the KLayout/kdb backend with kfactory 0.17.x APIs). System `gdsfactory9` is incompatible.
- Global Foundries `gf180mcuC`/`gf180mcuD`: pcells work with `gdsfactory==9.20.6`. The image pins the system `gdsfactory` to this version.

The image addresses these automatically (issue <https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/162>):
- A `gdsfactory==8.0.0` virtual environment is installed at `/foss/tools/klayout_gdsfactory8/`. When `sak-pdk sky130A` (or `sky130B`) is run, `KLAYOUT_PYTHONPATH` is set to this venv's `site-packages`. KLayout prepends `KLAYOUT_PYTHONPATH` to its embedded Python `sys.path`, so the sky130 pcell libraries load correctly.
- A `gdsfactory==9.20.6` virtual environment is installed at `/foss/tools/klayout_gdsfactory9/`. When `sak-pdk gf180mcuC` (or `gf180mcuD`) is run, `KLAYOUT_PYTHONPATH` is set to this venv's `site-packages`. KLayout prepends `KLAYOUT_PYTHONPATH` to its embedded Python `sys.path`, so the sky130 pcell libraries load correctly.

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

The IIC-OSIC-Tools container can be run using Podman instead of Docker (with the Podman Docker compatible CLI), but it introduces some issues:

- By default, Podman mounts all bind-mounts/volumes as root, even though the `UID` inside the container is != 0, which creates some problems when accessing files inside the container. To work around this issue, we suggest the following procedure:
- Edit the desired start script and find/replace all occurrences of `:rw` with `:U,rw`. Then Podman will mount all listed directories with the given `UID` inside the container.

For rootless Podman operation (which resolves X11/Wayland socket access issues), please refer to [Section 5.1 of the README](README.md#51-podman) and use `--userns=keep-id`.

### Docker Rootless Mode

Running Docker in rootless mode with X11/Wayland forwarding (`start_x.sh`) is not fully supported. The X11 and Wayland sockets are not accessible from the container due to UID/GID mismatches in the user namespace. There is no straightforward fix for Docker rootless mode.

**Workaround:** Switch to [Podman](https://podman.io/) in rootless mode with `--userns=keep-id` (see [Section 5.1 of the README](README.md#51-podman)). The `start_x.sh` script automatically detects Podman rootless mode and prints the required command.

### Palace EM-Setup

Volker Muehlaus' `setupEM`/`gds2palace` tool for AWS Palace is only installed for `x86_64`, as there are currently issues with `gmsh` for `arm64` on Linux.

### GDS3D crashing on macOS

At least since tag `2025.12` GDS3D is crashing with an error message. Unfortunately, there is no known fix at the moment. See <https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/220>.

### Xschem Library Path (IHP Open-PDK)

Since tag `2026.04`, the IHP Open-PDK changed its `xschemrc` (see commit https://github.com/IHP-GmbH/IHP-Open-PDK/commit/2bda257623753d0571bc40c5f50481e8389309e0), which adds a `sg13g2_pr/` prefix to all symbol paths. Schematics created with earlier container versions will show missing symbols.

This can be fixed by updating the symbol paths directly in the `.sch` files. Since `.sch` files from Xschem are text-based, a bulk find-and-replace in an editor is done quite fast. Another workaround is to add the PDK xschem library to `XSCHEM_USER_LIBRARY_PATH` in your `.designinit` (see issue https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/257):

```bash
export XSCHEM_USER_LIBRARY_PATH=${PDK_ROOT}/${PDK}/libs.tech/xschem:<your-project-xschem-path>
```

## Build

No known issues at the moment. However, be warned that building the image is quite involved and may take several hours depending on the host system performance and network connection. For a multi-architecture build (`amd64` + `arm64`) dedicated build servers with sufficient resources are recommended. Cross-architecture builds take ages and are not recommended. Plus, a private Docker registry is currently used by the build system to store intermediate build stages, which requires a fast network connection to the registry server.
