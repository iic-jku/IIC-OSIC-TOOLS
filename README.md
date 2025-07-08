# IIC-OSIC-TOOLS

[![DOI](https://zenodo.org/badge/477419126.svg)](https://doi.org/10.5281/zenodo.14387234)

This environment is based on the [efabless.com FOSS-ASIC-TOOLS](https://github.com/efabless/foss-asic-tools).

**IIC-OSIC-TOOLS** (Integrated Infrastructure for Collaborative Open Source IC Tools) is an all-in-one Docker container for open-source-based integrated circuit designs for analog and digital circuit flows. The CPU architectures `x86_64/amd64` and `aarch64/arm64` are natively supported based on Ubuntu 24.04 LTS (since release `2025.01`). This collection of tools is curated by the [**Department for Integrated Circuits (DIC), Johannes Kepler University (JKU)**](https://iic.jku.at).

## Table of Contents

- [IIC-OSIC-TOOLS](#iic-osic-tools)
  - [Table of Contents](#table-of-contents)
  - [1. How to Use These Open-Source (and Free) IC Design Tools](#1-how-to-use-these-open-source-and-free-ic-design-tools)
    - [1.1 Step 1: Clone/download this GitHub repository onto your computer](#11-step-1-clonedownload-this-github-repository-onto-your-computer)
    - [1.2 Step 2: Install Docker on your computer](#12-step-2-install-docker-on-your-computer)
    - [1.3 Step 3: Start and Use a Docker Container based on our IIC-OSIC-TOOLS Image](#13-step-3-start-and-use-a-docker-container-based-on-our-iic-osic-tools-image)
  - [2. Installed PDKs](#2-installed-pdks)
  - [3. Installed Tools](#3-installed-tools)
  - [4. Quick Launch for Designers](#4-quick-launch-for-designers)
    - [4.1 Customizing Environment](#41-customizing-environment)
    - [4.2 Using VNC and noVNC](#42-using-vnc-and-novnc)
      - [4.2.1 Variables for VNC](#421-variables-for-vnc)
    - [4.3 Using a Local X-Server](#43-using-a-local-x-server)
      - [4.3.1 Variables for X11](#431-variables-for-x11)
      - [4.3.2 macOS and Windows-specific Variables](#432-macos-and-windows-specific-variables)
      - [4.3.3 Linux-specific Variables](#433-linux-specific-variables)
      - [4.3.4 Installing X11-Server](#434-installing-x11-server)
    - [4.4 Overwriting Shell Variables](#44-overwriting-shell-variables)
      - [4.4.1 For the Linux/macOS Bash Scripts](#441-for-the-linuxmacos-bash-scripts)
      - [4.4.2 For the Windows Batch Scripts](#442-for-the-windows-batch-scripts)
    - [4.5 Using as devcontainer](#45-using-as-devcontainer)
      - [4.5.1 Add it to project](#451-add-it-to-project)
  - [5. Support with Issues/Problems/Bugs](#5-support-with-issuesproblemsbugs)

## 1. How to Use These Open-Source (and Free) IC Design Tools

**For great step-to-step instructions of installation and operation of our tool collection, please check out Kwantae Kim's [Setting Up Open Source Tools with Docker](https://kwantaekim.github.io/2024/05/25/OSE-Docker/)!**

It supports two *modes of operation*:

1. Using a complete desktop environment (XFCE) in `Xvnc` (a VNC server), either directly accessing it with a VNC client of your choice or the integrated [noVNC](https://novnc.com) server that runs in your browser.
2. Using a local X11 server and directly showing the application windows on your desktop.
3. Using it as a development container in Visual Studio Code (or other IDEs)

### 1.1 Step 1: Clone/download this GitHub repository onto your computer

Use the green **Code** button, and either download the zip file or do a

```bash
git clone --depth=1 https://github.com/iic-jku/iic-osic-tools.git
```

### 1.2 Step 2: Install Docker on your computer

See instructions on how to do this in the section [**Quick Launch for Designers**](#4-quick-launch-for-designers) further down in this `README`.

### 1.3 Step 3: Start and Use a Docker Container based on our IIC-OSIC-TOOLS Image

Enter the directory of this repository on your computer, and use one of the methods described in the section [**Quick Launch for Designers**](#4-quick-launch-for-designers) to start up and run a Docker container based on our image. The easiest way is probably to use the **VNC** mode.

If you do this the first time, or we have pushed an updated image to DockerHub, this can take a while since the image is pulled (loaded) automatically from DockerHub. Since this image is ca. 4 GB, this takes time, depending on your internet speed. Please note that this compressed image will be extracted on your drive, so please provide at least **20 GB of free drive space**. If, after a while, the consumed space gets larger, this may be due to unused images piling up. In this case, delete old ones; please consult the internet for instructions on operating Docker.

If you know what you are doing and want full root access without a graphical interface, please use

```bash
./start_shell.sh
```

## 2. Installed PDKs

As of the `2022.12` tag, the following open-source process-development kits (PDKs) are pre-installed, and the table shows how to switch by setting environment variables (you can do this per project by putting this into `.designinit` as explained below):

| SkyWater Technologies `sky130A` |
|---|

```bash
export PDK=sky130A
export PDKPATH=$PDK_ROOT/$PDK
export STD_CELL_LIBRARY=sky130_fd_sc_hd
export SPICE_USERINIT_DIR=$PDKPATH/libs.tech/ngspice
export KLAYOUT_PATH=$PDKPATH/libs.tech/klayout:$PDKPATH/libs.tech/klayout/tech
```

| Global Foundries `gf180mcuC` |
|---|

```bash
export PDK=gf180mcuC
export PDKPATH=$PDK_ROOT/$PDK
export STD_CELL_LIBRARY=gf180mcu_fd_sc_mcu7t5v0
export SPICE_USERINIT_DIR=$PDKPATH/libs.tech/ngspice
export KLAYOUT_PATH=$PDKPATH/libs.tech/klayout:$PDKPATH/libs.tech/klayout/tech
```

| IHP Microelectronics `ihp-sg13g2` |
|---|

```bash
export PDK=ihp-sg13g2
export PDKPATH=$PDK_ROOT/$PDK
export STD_CELL_LIBRARY=sg13g2_stdcell
export SPICE_USERINIT_DIR=$PDKPATH/libs.tech/ngspice
export KLAYOUT_PATH=$PDKPATH/libs.tech/klayout:$PDKPATH/libs.tech/klayout/tech
```

Probably the best way to switch between PDKs is to use the command `sak-pdk`. When called without arguments a list of installed PDKs is shown. To e.g. switch to IHP enter

```bash
sak-pdk ihp-sg13g2
```

or to switch to sky130A enter

```bash
sak-pdk sky130A
```

More options for selecting digital standard cell libraries are available; please check the PDK directories.

## 3. Installed Tools

Below is a list of the current tools/PDKs already installed and ready to use:

- [abc](https://github.com/berkeley-abc/abc) sequential logic synthesis and formal verification
- [amaranth](https://github.com/amaranth-lang/amaranth) a Python-based HDL tool chain
- [cace](https://github.com/efabless/cace) a Python-based circuit automatic characterization engine
- [charlib](https://github.com/stineje/CharLib) a characterization library for standard cells
- [ciel](https://github.com/fossi-foundation/ciel) version manager (and builder) for open-source PDKs
- [cocotb](https://github.com/cocotb/cocotb) simulation library for writing VHDL and Verilog test benches in Python
- [covered](https://github.com/hpretl/verilog-covered) Verilog code coverage
- [cvc](https://github.com/d-m-bailey/cvc) circuit validity checker (ERC)
- [edalize](https://github.com/olofk/edalize) Python abstraction library for EDA tools
- [fault](https://github.com/AUCOHL/Fault) design-for-testing (DFT) solution
- [fusesoc](https://github.com/olofk/fusesoc) package manager and build tools for SoC
- [gaw3-xschem](https://github.com/StefanSchippers/xschem-gaw) waveform plot tool for `xschem`
- [gds3d](https://github.com/trilomix/GDS3D) a 3D viewer for GDS files
- [gdsfactory](https://github.com/gdsfactory/gdsfactory) Python library for GDS generation
- [gdspy](https://github.com/heitzmann/gdspy) Python module for the creation and manipulation of GDS files
- [gf180mcu](https://github.com/google/gf180mcu-pdk) GlobalFoundries 180 nm CMOS PDK
- [ghdl-yosys-plugin](https://github.com/ghdl/ghdl-yosys-plugin) VHDL-plugin for `yosys`
- [ghdl](https://github.com/ghdl/ghdl) VHDL simulator
- [gtkwave](https://github.com/gtkwave/gtkwave) waveform plot tool for digital simulation
- [hdl21](https://github.com/dan-fritchman/Hdl21) analog hardware description library
- [ihp-sg13g2](https://github.com/IHP-GmbH/IHP-Open-PDK) IHP Microelectronics 130 nm SiGe:C BiCMOS PDK (partial PDK, not fully supported yet; `xschem` and `ngspice` simulation works incl. PSP MOSFET model)
- [irsim](https://github.com/rtimothyedwards/irsim) switch-level digital simulator
- [iverilog](https://github.com/steveicarus/iverilog) Verilog simulator
- [kactus2](https://github.com/kactus2/kactus2dev) Kactus2 is a graphical editor for IP-XACT files, which are used to describe hardware components and their interfaces
- [klayout-pex](https://github.com/martinjankoehler/klayout-pex) parasitic extraction for `klayout`
- [klayout](https://github.com/KLayout/klayout) layout viewer and editor for GDS and OASIS
- [lctime](https://codeberg.org/librecell/lctime) Characterization kit for CMOS cells
- [libman](https://github.com/IHP-GmbH/LibMan) design library manager to manage cells and views
- [magic](https://github.com/rtimothyedwards/magic) layout editor with DRC and PEX
- [najaeda](https://github.com/najaeda/naja) data structures and APIs for the development of post logic synthesis EDA algorithms
- [netgen](https://github.com/rtimothyedwards/netgen) netlist comparison (LVS)
- [ngspice](http://ngspice.sourceforge.net) SPICE analog and mixed-signal simulator, with OSDI support
- [ngspyce](https://github.com/ignamv/ngspyce) Python bindings for `ngspice`
- [nvc](https://github.com/nickg/nvc) VHDL simulator and compiler
- [open_pdks](https://github.com/RTimothyEdwards/open_pdks) PDK setup scripts
- [openems](https://github.com/thliebig/openEMS) electromagnetic field solver using the EC-FDTD method
- [openlane2](https://github.com/efabless/openlane2) rewrite of OpenLane in Python, 2nd generation
- [openram](https://github.com/VLSIDA/OpenRAM) OpenRAM Python library
- [openroad](https://github.com/The-OpenROAD-Project/OpenROAD) RTL2GDS engine used by `openlane2`
- [opensta](https://github.com/parallaxsw/OpenSTA) gate level static timing verifier
- [openvaf](https://github.com/dwarning/OpenVAF) Verilog-A compiler for device models
- [osic-multitool](https://github.com/iic-jku/osic-multitool) collection of useful scripts and documentation
- [padring](https://github.com/donn/padring) padring generation tool
- [pulp-tools](https://github.com/pulp-platform/pulp) PULP platform tools consisting of [bender](https://github.com/pulp-platform/bender), [morty](https://github.com/pulp-platform/morty), [svase](https://github.com/pulp-platform/svase), [verible](https://github.com/chipsalliance/verible), and [sv2v](https://github.com/zachjs/sv2v)
- [pygmid](https://github.com/dreoilin/pygmid) Python version of the gm/Id starter kit from Boris Murmann
- [pyopus](https://fides.fe.uni-lj.si/pyopus/index.html) simulation runner and optimization tool for analog circuits
- [pyrtl](https://github.com/UCSBarchlab/PyRTL) collection of classes for pythonic RTL design
- [pyspice](https://github.com/PySpice-org/PySpice) interface `ngspice` and `xyce` from Python
- [pyuvm](https://github.com/pyuvm/pyuvm) Universal Verification Methodology implemented in Python (instead of SystemVerilog) using `cocotb`
- [pyverilog](https://github.com/PyHDI/Pyverilog) Python toolkit for Verilog
- [qflow](https://github.com/RTimothyEdwards/qflow) collection of useful conversion tools
- [qucs-s](https://github.com/ra3xdh/qucs_s) simulation environment with RF emphasis
- [rggen](https://github.com/rggen/rggen) Code generation tool for control and status registers
- [risc-v toolchain](https://github.com/riscv/riscv-gnu-toolchain) GNU compiler toolchain for RISC-V cores
- [riscv-pk](https://github.com/riscv-software-src/riscv-pk) RISC-V proxy kernel and bootloader
- [schemdraw](https://github.com/cdelker/schemdraw) Python package for drawing electrical schematics
- [siliconcompiler](https://github.com/siliconcompiler/siliconcompiler) modular build system for hardware
- [sky130](https://github.com/google/skywater-pdk) SkyWater Technologies 130 nm CMOS PDK
- [slang yosys plugin](https://github.com/povik/yosys-slang) Slang-based plugin for `yosys` for SystemVerilog support
- [slang](https://github.com/MikePopoloski/slang) SystemVerilog parsing and translation (e.g. to Verilog)
- [spicelib](https://github.com/nunobrum/spicelib) library to interact with SPICE-like simulators
* [spike](https://github.com/riscv-software-src/riscv-isa-sim) Spike RISC-V ISA simulator
- [spyci](https://github.com/gmagno/spyci) analyze/plot `ngspice`/`xyce` output data with Python
- [surelog](https://github.com/chipsalliance/Surelog) SystemVerilog parser, elaborator, and UHDM compiler
- [surfer](https://gitlab.com/surfer-project/surfer) waveform viewer with snappy usable interface and extensibility
- [verilator](https://github.com/verilator/verilator) fast Verilog simulator
- [veryl](https://github.com/veryl-lang/veryl) a modern hardware description language, based on SystemVerilog
- [vlog2verilog](https://github.com/RTimothyEdwards/qflow) Verilog file conversion
- [vlsirtools](https://github.com/Vlsir/Vlsir) interchange formats for chip design.
- [xcircuit](https://github.com/RTimothyEdwards/XCircuit) schematic editor
- [xschem](https://github.com/StefanSchippers/xschem) schematic editor
- [xyce](https://github.com/Xyce/Xyce) fast parallel SPICE simulator (incl. `xdm` netlist conversion tool)
- [yosys](https://github.com/YosysHQ/yosys) Verilog synthesis tool (with GHDL plugin for VHDL synthesis and Slang plugin for SystemVerilog synthesis), incl. `eqy` (equivalence checker), `sby` (formal verification), and `mcy` (mutation coverage)
- RF toolkit with [FastHenry2](https://github.com/ediloren/FastHenry2), [FasterCap](https://github.com/ediloren/FasterCap), [openEMS](https://github.com/thliebig/openEMS), and [scikit-rf](https://github.com/scikit-rf/scikit-rf).

The tool versions used for `OpenLane2` (and other tools) are documented in `tool_metadata.yml`. In addition to the EDA tools above, further valuable tools (like `git`) and editors (like `gvim`) are installed. If something useful is missing, please let us know!

## 4. Quick Launch for Designers

Download and install **Docker** for your operating system:

- [All platforms (Linux)](https://docs.docker.com/engine/install/)
- [Windows](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe)
- [Mac with Intel Chip](https://desktop.docker.com/mac/main/amd64/Docker.dmg)
- [Mac with Apple Chip](https://desktop.docker.com/mac/main/arm64/Docker.dmg)

Note for Linux: Do not run docker commands or the start scripts as root (`sudo`)! Follow the instructions in [Post-installation steps for Linux](https://docs.docker.com/engine/install/linux-postinstall/)

The following start scripts are intended as helper scripts for local or small-scale (single instance) deployment. Consider starting the containers with a custom start script if you need to run many instances.

### 4.1 Customizing Environment

All user data is persistently placed in the directory pointed to by the environment variable `DESIGNS` (the default is `$HOME/eda/designs` for Linux/macOS and `%USERPROFILE%\eda\designs` for Windows, respectively).

If a file `.designinit` is put in this directory, it is sourced last when starting the Docker environment. In this way, users can adapt settings to their needs.

### 4.2 Using VNC and noVNC

This mode is recommended for remote operation on a separate server or if you prefer the convenience of a full desktop environment. To start it up, you can use (in a Bash/Unix shell):

```bash
./start_vnc.sh
```

On Windows, you can use the equivalent batch script (if the defaults are acceptable, it can also be started by double-clicking in Explorer):

```terminal
.\start_vnc.bat
```

You can now access the Desktop Environment through your browser ([http://localhost](http://localhost)). The default password is `abc123`.

#### 4.2.1 Variables for VNC

Both scripts will use default settings, which you can tweak by settings shell variables (`VARIABLE=default` is shown):

- `DRY_RUN` (unset by default); if set to any value (also `0`, `false`, etc.), the start scripts print all executed commands instead of running. Useful for debugging/testing or just creating "template commands" for unique setups.
- `DESIGNS=$HOME/eda/designs` (`DESIGNS=%USERPROFILE%\eda\designs` for `.bat`) sets the directory that holds your design files. This directory is mounted into the container on `/foss/designs`.
- `WEBSERVER_PORT=80` sets the port on which the Docker daemon will map the webserver port of the container to be reachable from localhost and the outside world. `0` disables the mapping.
- `VNC_PORT=5901` sets the port on which the Docker daemon will map the VNC server port of the container to be reachable from localhost and the outside world. This is only required to access the UI with a different VNC client. `0` disabled the mapping.
- `DOCKER_USER="hpretl"` username for the Docker Hub repository from which the images are pulled. Usually, no change is required.
- `DOCKER_IMAGE="iic-osic-tools"` Docker Hub image name to pull. Usually, no change is required.
- `DOCKER_TAG="latest"` Docker Hub image tag. By default, it pulls the latest version; this might be handy to change if you want to match a specific version set.
- `CONTAINER_USER=$(id -u)` (the current user's ID, `CONTAINER_USER=1000` for `.bat`) The user ID (and also group ID) is especially important on Linux and macOS because those are the IDs used to write files in the `DESIGNS` directory. For debugging/testing, the user and group ID can be set to `0` to gain root access inside the container.
- `CONTAINER_GROUP=$(id -g)` (the current user's group ID, `CONTAINER_GROUP=1000` for `.bat`)
- `CONTAINER_NAME="iic-osic-tools_xvnc_uid_"$(id -u)` (attaches the executing user's ID to the name on Unix, or only `CONTAINER_NAME="iic-osic-tools_xvnc` for `.bat`) is the name that is assigned to the container for easy identification. It is used to identify if a container exists and is running.

To overwrite the default settings, see [Overwriting Shell Variables](#44-overwriting-shell-variables)

### 4.3 Using a Local X-Server

This mode is recommended if the container is run on the local machine. It is significantly faster than VNC (as it renders the graphics locally), is more lightweight (no complete desktop environment is running), and integrates with the desktop (copy-paste, etc.). To start the container, run the following:

```bash
./start_x.sh
```

or

```terminal
.\start_x.bat
```

**Attention macOS users:** The X-server connection is automatically killed if there is a too-long idle period in the terminal (when this happens, it looks like a **crash** of the system). A **workaround** is to start a second terminal from the initial terminal that pops up when executing the start scripts `./start_x.sh` or `.\start_x.bat` and then start `htop` in the initial terminal. In this way, there is an ongoing display activity in the initial terminal, and as a positive side effect, the usage of the machine can be monitored. We are looking for a better long-term solution.

**Attention macOS users:** Please disable the *Enable VirtioFS accelerated directory sharing* setting available as "Beta Setting," as this will cause issues accessing the mounted drives! However, enabling the *VirtioFS* general setting works in Docker >v4.15.0!

#### 4.3.1 Variables for X11

The following environment variables are used for configuration:

- `DRY_RUN` (unset by default), if set to any value (also `0`, `false`, etc.), makes the start scripts print all executed commands instead of running. Useful for debugging/testing or just creating "template commands" for unique setups.
- `DESIGNS=$HOME/eda/designs` (`DESIGNS=%USERPROFILE%\eda\designs` for `.bat`) sets the directory that holds your design files. This directory is mounted into the container on `/foss/designs`.
- `DOCKER_USER="hpretl"` username for the Docker Hub repository from which the images are pulled. Usually, no change is required.
- `DOCKER_IMAGE="iic-osic-tools"` Docker Hub image name to pull. Usually, no change is required.
- `DOCKER_TAG="latest"` Docker Hub image tag. By default, it pulls the latest version; this might be handy to change if you want to match a specific Version set.
- `CONTAINER_USER=$(id -u)` (the current user's ID, `CONTAINER_USER=1000` for `.bat`) The user ID (and also group ID) is especially important on Linux and macOS because those are the IDs used to write files in the `DESIGNS` directory.
- `CONTAINER_GROUP=$(id -g)` (the current user's group ID, `CONTAINER_GROUP=1000` for `.bat`)
- `CONTAINER_NAME="iic-osic-tools_xserver_uid_"$(id -u)` (attaches the executing user's ID to the name on Unix, or only `CONTAINER_NAME="iic-osic-tools_xserver` for `.bat`) is the name that is assigned to the container for easy identification. It is used to identify if a container exists and is running.

#### 4.3.2 macOS and Windows-specific Variables

For Windows, WSLg (the graphical subsystem for WSL) is used, which is provided by a socket file inside the container. The display number is `:0`.
For Mac, the X11 server is accessed through TCP (defaults to `host.docker.internal:0`, `host.docker.internal` resolves to the host's IP address inside the docker containers, `:0` corresponds to display 0 which corresponds to TCP port 6000.).

Normally, it should not be necessary to modify these settings, but to control the server's address, you can set the following variable:

- `DISP` is the environment variable that is copied into the `DISPLAY` variable of the container.

For TCP based connections, access control might be modified. If the executable `xauth` is in `PATH`, the startup script automatically disables access control for localhost, so the X11 server is open for connections from the container. A warning will be shown if not, and you must disable access control.

#### 4.3.3 Linux-specific Variables

For Linux, the local X11 server is accessed through a Unix socket. There are multiple variables to control:

- `XSOCK=/tmp/.X11-unix` is typically the default location for the Unix sockets. The script will probe if it exists and, if yes, mount it into the container.
- `DISP` has the same function as macOS and Windows. It is copied to the container's `DISPLAY` variable. If it is not set, the value of `DISPLAY` from the host is copied.
- `XAUTH` defines the file that holds the cookies for authentication through the socket. If it is unset, the host's `XAUTHORITY` contents are used. If those are unset too, it will use `$HOME/.Xauthority`.

The defaults for these variables are tested on native X11 servers, X2Go sessions, and Wayland. The script copies and modifies the cookie from the`.Xauthority` file into a separate, temporary file. This file is then mounted into the container.

#### 4.3.4 Installing X11-Server

Everything should be ready on Linux with a desktop environment / UI (this setup has been tested on X11 and XWayland). For Windows, WSL should be updated to the latest version to provide WSLg (No additional X-Server needs to be installed, and it should be readily available on Windows 10 (from Build 19044) and Windows 11). For macOS, the installation of an X11 server is typically required. Due to the common protocol, every X11-server should work, although the following are tested:

- For macOS: [XQuartz](https://www.xquartz.org/) **Important:** Please enable *"Allow connections from network clients"* in the XQuartz preferences [CMD+","], tab *"Security"*

It is strongly recommended enabling OpenGL:

- The `start_x.sh` script will take care of that on macOS and set it according to configuration values. Only a manual restart of XQuartz is required after the script is run once (observe the output!).

### 4.4 Overwriting Shell Variables

#### 4.4.1 For the Linux/macOS Bash Scripts

There are multiple ways to configure the start scripts using Bash. Two of them are shown here. First, the variables can be set directly for each run of the script; they are not saved in the active session:

```bash
DESIGNS=/my/design/directory DOCKER_USERNAME=another_user ./start_x.sh
```

The second variant is to set the variables in the current shell session (not persistent between shell restarts or shared between sessions):

```bash
export DESIGNS=/my/design/directory
export DOCKER_USERNAME=another_user
./start_x.sh
```

As those variables are stored in your current shell session, you only have to set them once. After setting, you can directly run the scripts.

#### 4.4.2 For the Windows Batch Scripts

In `CMD` you can't set the variables directly when running the script. So for the `.bat` scripts, it is like the second variant for Bash scripts:

```batch
SET DESIGNS=\my\design\directory
SET DOCKER_USERNAME=another_user
.\start_x.bat
```

### 4.5 Using as devcontainer

This is a new usage mode, that might fit your needs. [Devcontainers](https://code.visualstudio.com/docs/devcontainers/containers) are a great way to provide a working build environment along your own project. It is supported by the [devcontainer](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension in Visual Studio Code.

#### 4.5.1 Add it to project

Option 1: In Visual Studio, click the remote window icon on the left and then "Reopen in Container", "Add configuration to workspace". Enter "ghcr.io/iic-jku/iic-osic-tools/devcontainer" as template, choose the version of the container and add more features (probably not needed). It will then restart the IDE, download the image and start a terminal and mount the work folder into the image.

Option 2: Alternatively you can directly just create the configuration file `.devcontainer/devcontainer.json`:

```json
{
 "name": "IIC-OSIC-TOOLS",
 "image": "ghcr.io/iic-jku/iic-osic-tools-devcontainer:2024.12"
}
```

Either way, the great thing is that you can now commit the file to repository and all developers will be asked if they want to reopen their development in this container, all they need is Docker and VS Code.

## 5. Support with Issues/Problems/Bugs

We are open to your questions about this container and are very thankful for your input! If you run into a problem, and you are sure it is a bug, please let us know by following this routine:

- Take a look at the [KNOWN_ISSUES](KNOWN_ISSUES.md) and the [RELEASE_NOTES](RELEASE_NOTES.md). Both these files can include problems that we are already aware of and maybe include a workaround.
- Check the existing [Issues](https://github.com/iic-jku/IIC-OSIC-TOOLS/issues) on GitHub and see if the problem has been reported already. If yes, please participate in the discussion and help by further collecting information.
- Is the problem in connection with the container, or rather a problem with a specific tool? If it is the second, please also check out the sources of the tool and further contact the maintainer!
- To help us fix the problem, please open an issue on GitHub and report the error. Please give us as much information as possible without being verbose, so filter accordingly. It is also fine to open an issue with very little information, we will help you to narrow down the source of the error.
- Finally, if you can exactly know how to fix the reported error, we are also happy if you open a pull request with a fix!

 Thank you for your cooperation!
