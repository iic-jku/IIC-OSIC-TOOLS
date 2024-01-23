# IIC-OSIC-TOOLS

This environment is based on the [efabless.com FOSS-ASIC-TOOLS](https://github.com/efabless/foss-asic-tools).

**IIC-OSIC-TOOLS** is an all-in-one Docker container for open-source-based integrated circuit designs for analog and digital circuit flows. The CPU architectures `x86_64/amd64` and `aarch64/arm64` are natively supported based on Ubuntu 22.04LTS (since release `2022.12`). This collection of tools is curated by the [**Institute for Integrated Circuits (IIC), Johannes Kepler University (JKU)**](https://iic.jku.at).

It supports two *modes of operation*:

1. Using a complete desktop environment (XFCE) in `Xvnc` (a VNC server), either directly accessing it with a VNC client of your choice or the integrated [noVNC](https://novnc.com) server that runs in your browser.
2. Using a local X11 server and directly showing the application windows on your desktop.

## How to Use These Open-Source (and Free) IC Design Tools

### Step 1: Clone/download this GitHub repository onto your computer

Use the green **Code** button, and either download the zip file or do a `git clone --depth=1 https://github.com/iic-jku/iic-osic-tools.git`.

### Step 2: Install Docker on your computer

See instructions on how to do this in the section [**Quick Launch for Designers**](#quick-launch-for-designers) further down in this `README`.

### Step 3: Start and Use a Docker Container based on our IIC-OSIC-TOOLS Image

Enter the directory of this repository on your computer, and use one of the methods described in the section [**Quick Launch for Designers**](#quick-launch-for-designers) to start up and run a Docker container based on our image. The easiest way is probably to use the **VNC** mode.

If you do this the first time, or we have pushed an updated image to DockerHub, this can take a while since the image is pulled (loaded) automatically from DockerHub. Since this image is ca. 4GB, this takes time, depending on your internet speed. Please note that this compressed image will be extracted on your drive, so please provide at least **20GB of free drive space**. If, after a while, the consumed space gets larger, this is maybe due to unused images piling up. In this case, delete old ones; please consult the internet for instructions on operating Docker.

If you know what you are doing and want full root access without a graphical interface, please use `./start_shell.sh`.

## Installed PDKs

As of the `2022.12` tag, the following open-source process-development kits (PDKs) are pre-installed, and the table shows how to switch by setting environment variables (you can do this per project by putting this into `.designinit` as explained below):

| SkyWater Technologies `sky130A` |
|---|
| `export PDK=sky130A` |
| `export PDKPATH=$PDK_ROOT/$PDK` |
| `export STD_CELL_LIBRARY=sky130_fd_sc_hd` |

| Global Foundries `gf180mcuC` |
|---|
| `export PDK=gf180mcuC` |
| `export PDKPATH=$PDK_ROOT/$PDK` |
| `export STD_CELL_LIBRARY=gf180mcu_fd_sc_mcu7t5v0` |

| IHP Microelectronics `sg13g2` |
|---|
| Not yet ready to use |

More options for selecting digital standard cell libraries are available; please check the PDK directories.

## Installed Tools

Below is a list of the current tools already installed and ready to use (note there are some adaptions in our container vs. efabless.com):

* [align](https://github.com/ALIGN-analoglayout/ALIGN-public) automatic layout generation for analog circuits (only on `amd64` and for `sky130` PDK)
* [amaranth](https://github.com/amaranth-lang/amaranth) a Python-based HDL toolchain
* [bag2](https://gitlab.com/mosaic_group/mosaic_BAG/opensource_db_template) Python-based analog layout generation and schematic transformation
* [cocotb](https://github.com/cocotb/cocotb) simulation library for writing VHDL and Verilog test benches in Python
* [covered](https://github.com/hpretl/verilog-covered) Verilog code coverage
* [cvc](https://github.com/d-m-bailey/cvc) circuit validity checker (ERC)
* [edalize](https://github.com/olofk/edalize) Python abstraction library for EDA tools
* [fault](https://github.com/Cloud-V/Fault) design-for-test (DFT) solution
* [fusesoc](https://github.com/olofk/fusesoc) package manager and build tools for SoC
* [gaw3-xschem](https://github.com/StefanSchippers/xschem-gaw.git) waveform plot tool for `xschem`
* [gdsfactory](https://github.com/gdsfactory/gdsfactory) Python library for GDS generation
* [gdspy](https://github.com/heitzmann/gdspy) Python module for creation and manipulation of GDS files
* [gds3d](https://github.com/trilomix/GDS3D) a 3D viewer for GDS files
* [gf180mcu](https://github.com/google/gf180mcu-pdk) GlobalFoundries 180nm CMOS PDK
* [ghdl](https://github.com/ghdl/ghdl) VHDL simulator
* [gtkwave](https://github.com/gtkwave/gtkwave) waveform plot tool for digital simulation
* [sg13g2](https://github.com/IHP-GmbH/IHP-Open-PDK) IHP Microelectronics 130nm SiGe:C BiCMOS PDK (partial PDK, not fully supported yet; `xschem` and `ngspice` simulation works incl. PSP MOSFET model)
* [irsim](https://github.com/rtimothyedwards/irsim) switch-level digital simulator
* [iverilog](https://github.com/steveicarus/iverilog.git) Verilog simulator
* [hdl21](https://github.com/dan-fritchman/Hdl21) Analog hardware description library
* [klayout](https://github.com/KLayout/klayout) layout viewer and editor for GDS and OASIS
* [magic](https://github.com/rtimothyedwards/magic) layout editor with DRC and PEX
* [netlistsvg](https://github.com/nturley/netlistsvg) draws SVG netlist from a `yosys` JSON netlist
* [netgen](https://github.com/rtimothyedwards/netgen) netlist comparison (LVS)
* [ngspice](http://ngspice.sourceforge.net) SPICE analog and mixed-signal simulator, with OSDI support
* [ngspyce](https://github.com/ignamv/ngspyce) Python bindings for `ngspice`
* [nvc](https://github.com/nickg/nvc) VHDL simulator and compiler
* [open_pdks](https://github.com/RTimothyEdwards/open_pdks) PDK setup scripts
* [openlane](https://github.com/The-OpenROAD-Project/OpenLane) digital RTL2GDS flow
* [openlane2](https://github.com/efabless/openlane2) rewrite of OpenLane in Python, 2nd generation
* [openram](https://github.com/VLSIDA/OpenRAM) OpenRAM Python library
* [openroad](https://github.com/The-OpenROAD-Project/OpenROAD.git) RTL2GDS engine used by `openlane` and `openlane2`
* [osic-multitool](https://github.com/iic-jku/osic-multitool.git) collection of useful scripts and documentation
* [padring](https://github.com/donn/padring) padring generation tool
* [pyopus](https://fides.fe.uni-lj.si/pyopus/index.html) simulation runner and optimization tool for analog circuits
* [pyrtl](https://github.com/UCSBarchlab/PyRTL) collection of classes for pythonic RTL design
* [pyspice](https://github.com/PySpice-org/PySpice) interface `ngspice` and `xyce` from Python
* [pyverilog](https://github.com/PyHDI/Pyverilog) Python toolkit for Verilog
* RF toolkit with [FastHenry2](https://github.com/ediloren/FastHenry2), [FasterCap](https://github.com/ediloren/FasterCap), [openEMS](https://github.com/thliebig/openEMS), and [scikit-rf](https://github.com/scikit-rf/scikit-rf).
* [qucs-s](https://github.com/ra3xdh/qucs_s) simulation environment with RF emphasis
* [rggen](https://github.com/rggen/rggen) code generation tool for configuration and status registers
* [spyci](https://github.com/gmagno/spyci) analyze/plot `ngspice`/`xyce` output data with Python
* [slang](https://github.com/MikePopoloski/slang) SystemVerilog parsing and translation (e.g. to Verilog)
* [vlog2verilog](https://github.com/RTimothyEdwards/qflow.git) Verilog file conversion
* [volare](https://github.com/efabless/volare) version manager (and builder) for open-source PDKs
* [risc-v toolchain](https://github.com/riscv/riscv-gnu-toolchain) GNU compiler toolchain for RISC-V RV32I cores
* [siliconcompiler](https://github.com/siliconcompiler/siliconcompiler) modular build system for hardware
* [sky130](https://github.com/google/skywater-pdk.git) SkyWater Technologies 130nm CMOS PDK
* [verilator](https://github.com/verilator/verilator) fast Verilog simulator
* [vlsirtools](https://github.com/Vlsir/Vlsir) Interchange formats for chip design.
* [xschem](https://github.com/StefanSchippers/xschem.git) schematic editor
* [xyce](https://github.com/Xyce/Xyce.git) fast parallel SPICE simulator (incl. `xdm` netlist conversion tool)
* [yosys](https://github.com/YosysHQ/yosys) Verilog synthesis tool (with GHDL plugin for VHDL synthesis), incl. `eqy` (equivalence checker), `sby` (formal verification), and `mcy` (mutation coverage)

The tool versions used for `OpenLane` are documented in `tool_metadata.yml` and the other tools in `tool_metadata_add.yml`. In addition to the EDA tools above, further valuable tools (like `git`) and editors (like `gvim`) are installed. If something useful is missing, please let us know!

## Quick Launch for Designers

Download and install **Docker** for your operating system:

* [All platforms (Linux)](https://docs.docker.com/engine/install/)
* [Windows](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe)
* [Mac with Intel Chip](https://desktop.docker.com/mac/main/amd64/Docker.dmg)
* [Mac with Apple Chip](https://desktop.docker.com/mac/main/arm64/Docker.dmg)

Note for Linux: Do not run docker commands or the start scripts as root (`sudo`)! Follow the instructions in [Post-installation steps for Linux](https://docs.docker.com/engine/install/linux-postinstall/)

The following start scripts are intended as helper scripts for local or small-scale (single instance) deployment. Consider starting the containers with a custom start script if you need to run many instances.

### Customizing Environment

All user data is persistently placed in the directory pointed to by the environment variable `DESIGNS` (the default is `$HOME/eda/designs` for Linux/macOS and `%USERPROFILE%\eda\designs` for Windows, respectively).

If a file `.designinit` is put in this directory, it is sourced last when starting the Docker environment. In this way, users can adapt settings to their needs.

### Using VNC and noVNC

This mode is recommended for remote operation on a separate server or if you prefer the convenience of a full desktop environment. To start it up, you can use (in a Bash/Unix shell):

```bash
./start_vnc.sh
```

On Windows, you can use the equivalent batch script (if the defaults are acceptable, it can also be started by double-clicking in Explorer):

```terminal
.\start_vnc.bat
```

You can now access the Desktop Environment through your browser ([http://localhost](http://localhost)). The default password is `abc123`.

#### Variables for VNC

Both scripts will use default settings, which you can tweak by settings shell variables (`VARIABLE=default` is shown):

* `DRY_RUN` (unset by default); if set to any value (also `0`, `false`, etc.), the start scripts print all executed commands instead of running. Useful for debugging/testing or just creating "template commands" for unique setups.
* `DESIGNS=$HOME/eda/designs` (`DESIGNS=%USERPROFILE%\eda\designs` for `.bat`) sets the directory that holds your design files. This directory is mounted into the container on `/foss/designs`.
* `WEBSERVER_PORT=80` sets the port on which the Docker daemon will map the webserver port of the container to be reachable from localhost and the outside world. `0` disables the mapping.
* `VNC_PORT=5901` sets the port on which the Docker daemon will map the VNC server port of the container to be reachable from localhost and the outside world. This is only required to access the UI with a different VNC client. `0` disabled the mapping.
* `DOCKER_USER="hpretl"` username for the Docker Hub repository from which the images are pulled. Usually, no change is required.
* `DOCKER_IMAGE="iic-osic-tools"` Docker Hub image name to pull. Usually, no change is required.
* `DOCKER_TAG="latest"` Docker Hub image tag. By default, it pulls the latest version; this might be handy to change if you want to match a specific version set.
* `CONTAINER_USER=$(id -u)` (the current user's ID, `CONTAINER_USER=1000` for `.bat`) The user ID (and also group ID) is especially important on Linux and macOS because those are the IDs used to write files in the `DESIGNS` directory. For debugging/testing, the user and group ID can be set to `0` to gain root access inside the container.
* `CONTAINER_GROUP=$(id -g)` (the current user's group ID, `CONTAINER_GROUP=1000` for `.bat`)
* `CONTAINER_NAME="iic-osic-tools_xvnc_uid_"$(id -u)` (attaches the executing user's id to the name on Unix, or only `CONTAINER_NAME="iic-osic-tools_xvnc` for `.bat`) is the name that is assigned to the container for easy identification. It is used to identify if a container exists and is running.

To overwrite the default settings, see [Overwriting Shell Variables](#overwriting-shell-variables)

### Using a Local X-Server

This mode is recommended if the container is run on the local machine. It is significantly faster than VNC (as it renders the graphics locally), is more lightweight (no complete desktop environment is running), and integrates with the desktop (copy-paste, etc.). To start the container, run the following:

```bash
./start_x.sh
```

or

```terminal
.\start_x.bat
```

**Attention Windows and macOS users:** The X-server connection is automatically killed if there is a too-long idle period in the terminal (when this happens, it looks like a **crash** of the system). A **workaround** is to start a second terminal from the initial terminal that pops up when executing the start scripts `./start_x.sh` or `.\start_x.bat` and then start `htop` in the initial terminal. In this way, there is an ongoing display activity in the initial terminal, and as a positive side-effect, the usage of the machine can be monitored. We are looking for a better long-term solution.

**Attention macOS users:** Please disable the *Enable VirtioFS accelerated directory sharing* setting available as "Beta Setting," as this will cause issues accessing the mounted drives! However, enabling the *VirtioFS* general setting works in Docker >v4.15.0!

#### Variables for X11

The following environment variables are used for configuration:

* `DRY_RUN` (unset by default), if set to any value (also `0`, `false`, etc.), makes the start scripts print all executed commands instead of running. Useful for debugging/testing or just creating "template commands" for unique setups.
* `DESIGNS=$HOME/eda/designs` (`DESIGNS=%USERPROFILE%\eda\designs` for `.bat`) sets the directory that holds your design files. This directory is mounted into the container on `/foss/designs`.
* `DOCKER_USER="hpretl"` username for the Docker Hub repository from which the images are pulled. Usually, no change is required.
* `DOCKER_IMAGE="iic-osic-tools"` Docker Hub image name to pull. Usually, no change is required.
* `DOCKER_TAG="latest"` Docker Hub image tag. By default, it pulls the latest version; this might be handy to change if you want to match a specific Version set.
* `CONTAINER_USER=$(id -u)` (the current user's ID, `CONTAINER_USER=1000` for `.bat`) The user ID (and also group ID) is especially important on Linux and macOS because those are the IDs used to write files in the `DESIGNS` directory.
* `CONTAINER_GROUP=$(id -g)` (the current user's group ID, `CONTAINER_GROUP=1000` for `.bat`)
* `CONTAINER_NAME="iic-osic-tools_xserver_uid_"$(id -u)` (attaches the executing user's id to the name on Unix, or only `CONTAINER_NAME="iic-osic-tools_xserver` for `.bat`) is the name that is assigned to the container for easy identification. It is used to identify if a container exists and is running.

#### macOS and Windows-specific Variables

For Mac and Windows, the X11 server is accessed through TCP (`:0`, aka port 6000). To control the server's address, you can set the following variable:

* `DISP=host.docker.internal:0` is the environment variable that is copied into the `DISPLAY` variable of the container. `host.docker.internal` resolves to the host's IP address inside the docker containers, `:0` corresponds to display 0 which corresponds to TCP port 6000.

If the executable `xauth` is in `PATH`, the startup script automatically disables access control for localhost, so the X11 server is open for connections from the container. A warning will be shown if not, and you must disable access control.

#### Linux-specific Variables

For Linux, the local X11 server is accessed through a Unix socket. There are multiple variables to control:

* `XSOCK=/tmp/.X11-unix` is typically the default location for the Unix sockets. The script will probe if it exists and, if yes, mount it into the container.
* `DISP` has the same function as macOS and Windows. It is copied to the container's `DISPLAY` variable. If it is not set, the value of `DISPLAY` from the host is copied.
* `XAUTH` defines the file that holds the cookies for authentication through the socket. If it is unset, the host's `XAUTHORITY` contents are used. If those are unset too, it will use `$HOME/.Xauthority`.

The defaults for these variables are tested on native X11 servers, X2Go sessions, and Wayland. The script copies and modifies the cookie from the`.Xauthority` file into a separate, temporary file. This file is then mounted into the container.

#### Installing X11-Server

Everything should be ready on Linux with a desktop environment / UI (this setup has been tested on X11 and XWayland). For Windows and macOS, the installation of an X11 server is typically required. Due to the common protocol, every X11-server should work, although the following are tested:

* For Windows: [VcXsrc](https://sourceforge.net/projects/vcxsrv/)
* For macOS: [XQuartz](https://www.xquartz.org/) **Important:** Please enable *"Allow connections from network clients"* in the XQuartz preferences [CMD+","], tab *"Security"*

For both X-Servers, it is strongly recommended to enable OpenGL:

* The `start_x.sh` script will take care of that on macOS and set it according to configuration values. Only a manual restart of XQuartz is required after the script is run once (observe the output!).
* On Windows with VcXsrv, we recommend using the utility "XLaunch" (installed with VcXsrv):

  * Multiple windows mode
  * Set the Display Number to 0
  * Start no client
  * Tick all `Extra settings`: `Clipboard`, `Primary selection`, `Native opengl`, and `Disable access control`

### Overwriting Shell Variables

#### For the Linux/macOS Bash Scripts

There are multiple ways to configure the start scripts using Bash. Two of them are shown here. First, the variables can be set directly for each run of the script; they are not saved in the active session:

`DESIGNS=/my/design/directory DOCKER_USERNAME=another_user ./start_x.sh`

The second variant is to set the variables in the current shell session (not persistent between shell restarts or shared between sessions):

```bash
export DESIGNS=/my/design/directory
export DOCKER_USERNAME=another_user
./start_x.sh
```

As those variables are stored in your current shell session, you only have to set them once. After setting, you can directly run the scripts.

#### For the Windows Batch Scripts

In `CMD` you can't set the variables directly when running the script. So for the `.bat` scripts, it is like the second variant for Bash scripts:

```batch
SET DESIGNS=\my\design\directory
SET DOCKER_USERNAME=another_user
.\start_x.bat
```
