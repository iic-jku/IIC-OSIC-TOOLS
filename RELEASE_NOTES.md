# IIC-OSIC-TOOLS Release Notes

This document summarizes the most important changes of the individual releases of the `IIC-OSIC-TOOLS` Docker container.

## 2025.04

* **ATTENTION**: The default PDK has been switched to `ihp-sg13g2` (from `sky130A`).
* Startup scripts now feature a quiet mode when `IIC_OSIC_TOOLS_QUIET` is set.
* Adding `librelane` (successor to `openlane`) and `ciel` (successor to `volare`).
* Bump various tool versions (note that we keep `gdsfactory` a bit older because we need to stick with `klayout` v0.29.x for now).
* [Maintenance] The important scripts from `osic-multitool` are now part of `iic-osic-tools` to make maintenance easier.
* [Maintenance] The handling of `rust` and `cargo` have been streamlined.
* Removed the contents of the `sak` folder from the image.
* Temporarily remove `klayout-pex` due to `klayout` version clash.

## 2025.03

* **ATTENTION**: The symbol configuration of the LV- and HV-NMOS has changed in the IHP PDK in this release (drain and source have been swapped). Please adapt your existing IHP schematics accordingly!
* Changed Windows `start_x.bat` to use WSL integrated WSLg audio and visual subsystem instead of a third-party X-server.
* Changed Linux `start_x.sh` to support Wayland and provide more robust parameter handling.
* Adding `mold` and `ccache` to speed up `verilator` simulations.
* Add `pygame` for IIC-RALF.
* Add `nevergrad` for optimization (e.g., in Jupyter notebooks).
* Bump various tool versions.
* Store `ORFS` git hash in image (see `KNOWN_ISSUES.md`).

## 2025.02

* Adding `spicelib` SPICE-simulator interaction from Python.
* Adding `klayout-pex` parasitic extraction tool.
* Adding a couple of useful Python packages (`numpy`, `pandas`, `plotly`, `pygmid`, `schemdraw`, `scipy`, `sympy`).
* Adapting to changed directory structure of IHP's PDK.
* Remove temporarily `hdl21` and `vlsirtools` due to incompatibility with `gdsfactory` on `pydantic`.
* Build `adms` from source, compile `xyce` models with it.
* Bump various tool versions.

## 2025.01

* Upgrade base OS to Ubuntu 24.04 LTS (from 22.04 LTS).
* Significantly reduced the Docker image size with various measures:
  * Remove the debug symbols from the RISC-V toolchain and strip the executables
  * Remove the KLayout testing folders (most users will never need them)
  * Remove dedicated build of `spike` as it is a part of the RISC-V toolchain
  * Remove the device measurements (MDM files) for the SG13G2 PDK
  * Use gzip`ed Liberty files for all PDKs
* Rename SG13G2 PDK location from `sg13g2` to `ihp-sg13g2` to be compatible to upstream.
* Fix the PSP models for `xyce`, add `adms` model compiler along the way. Enable external model support for `xyce`.
* Fix wrong symbol paths (caused upstream) of `xschem` test schematics for `gf180mcuC` and `gf180mcuD`.
* Re-add `hdl21` and `vlsirtools`.
* Adding `surfer` waveform viewer.
* Adding `lctime` CMOS cell characterization kit.
* Adding `qalculate` to have an onboard calculator.
* Adding a simple viewer for `.md` files (called `mdview`)
* Adding analog circuit design course files.
* Bump various tool versions.

## 2024.12

* Install OpenROAD twice: The required version for OpenLane2, and the latest version to be used for the OpenROAD Flow Scripts (ORFS). The `PATH` points to the OL2 version.
* Locally build `spdlog` (for OpenROAD) and `bottleneck` to fix warning in `gdsfactory` and `scikit-rf`.
* Added additional high display resolutions for VNC mode.
* Bump various tool versions.

## 2024.11

* Add useful keybindings to KLayout, set `KLAYOUT_PATH` properly.
* Bump various tool versions.

## 2024.10

* Adding support for devcontainers (for use of the image inside VSCode).
* Enable `pyosys` when building `yosys` (for use with OpenLane2).
* Adding `pytest` (for, e.g., `cocotb`).
* Add writing the users' data directory to `eda_server_start.sh`, and write the full VM name in the json file.
* Bump various tool versions.
* Get `xyce` sourcecode from Sandia homepage instead of GitHub.

## 2024.09

* Add `slang` plugin for `yosys` for direct SystemVerilog read-in.
* Add `spike` RISC-V ISA simulator.
* Add `riscv-pk` proxy kernel and boot loader.
* Add `jq` for CLI JSON processing.
* Bump various tool versions.
* Fixed `ngspice` simulation issue with `sky130A`.
* Remove a few outdated WA.
* Remove `synlig` `yosys` plugin (depreciated).

## 2024.08

* Add testsuite for image release testing (very basic at this stage).
* Add required tools for PULP-platform (`morty`, `bender`, `svase`, `sv2v`, `verible`).
* Add RISC-V GNU tool chain back in, as the PULP-platform is using it.
* Add `surelog`.
* Add `pygmid`.
* Add `xcircuit`.
* Bump various tool and PDK versions.
* Fix VHDL flow in OpenLane2.
* Simplify tool directory structure by removing the tool GitHub hashes from the directory tree (the original intention was to be able to install different tool versions in parallel, but this was never really used).
* Adapt the Docker build script to use our new ARM build server. Now we build the image in parallel on two 100+ cores `aarch64` and `amd64` machines.
* Adapt all tool build scripts to work in `/tmp`.
* Move install for as many Python packages as possible from APT to PIP (to enable newer versions).
* Remove alias for `xschem` and `magic`, instead properly install RC files in `/headless`.
* Remove `netlistsvg`, as it is requiring the large node.js package.
* Remove `hdl21` and `vlsirtools` to allow `numpy` 2.

## 2024.07

* Bump various tool versions.
* Include an example for `cace`.
* Add `pyuvm`.
* Adding BSIMCMG model for `ngspice`.
* Remove `gdstk` due to build issues.

## 2024.05

* Changing from OpenLane(1) to OpenLane2! OpenLane(1) is removed from the image. The tool versions used by OpenLane2 are now set to latest release (or if necessary the version required by OL2), instead of pinned (older) versions. This impacts the following tools:

  * Magic
  * Netgen
  * OpenROAD
  * OpenSTA
  * Yosys
  * PDK version
  * Padring
* Remove ALIGN (has only been included in `amd64` version, not in `arm64`).
* Update various tool versions.

## 2024.04

* This will be the last release using OpenLane(1). We will switch to OpenLane2 going forward.
* Remove `fault` (and `atalanta` and Swift).
* Update various tool versions.

## 2024.03

* Add `synlig` (SystemVerilog plugin for Yosys).
* Add Python packages for [IIC-RALF](https://github.com/iic-jku/IIC-RALF).
* Add simple analog (inverter) and digital (counter) design examples in `/foss/examples`.
* Add `libman` as a proposal for a design manager.
* Add `cace` and `schemdraw` packages.
* Create `KNOWN_ISSUES.md` to document issues and work to do.
* Update various tool versions.
* Remove RISC-V toolchain to reduce image size.
* Cleanup of build process to reduce image size.

## 2024.01

* Fix `PyOPUS` and `matplotlib` (and therewith `openems`. Please see the known issues for a persisting problem).
* Adding `virtualenv`.
* Adding `gf180mcuD` PDK flavor.
* Bump various tool versions.

## 2023.12

* `OpenVAF` is built from source during the image build.
* Adding `scikit-rf` and `schemdraw`.
* Update `ngspice` to support KLU (fast solver) and Verilog co-simulation.
* Update `OpenVAF` to enable MOS-FET noise simulation.
* Update `gtkwave` to the new build system.
* Update various tool versions.
* Remove `gcc-9` to reduce image size.

## 2023.10

* Setup `xschem` and `ngspice` simulation for `sg13g2`.
* Moved Docker build-related stuff into `_build` directory.
* Add GitHub `CITATION.ff` for automatic citation support.
* Adding `eqy` (equivalence checker), `sby` (formal verification), and `mcy` (mutation coverage) for `yosys`.
* Upgrade to `LLVM-15`/`Clang-15` to slim down image. Remove `GCC-10` as well.
* Update various tool versions.
* Removes various examples from `/foss/examples` folder to reduce image size.

## 2023.09

* Update various tool versions.
* Added `hdl21` and `vlsirtools`.

## 2023.08

* Update various tool versions.
* Remove PDK `sky130B` to reduce image size.
* Added `align` package (only for `amd64` and using `sky130` PDK, `arm64` postponed due to build fails).
* Added `slang` (can be used for SystemVerilog to Verilog translation).
* Fixed a few issues along the way.

## 2023.06

* Added `Qucs-S` and `PyOPUS`.
* Fix XFCE configuration (background and other settings).
* Cleanup of the startup script (container stops when subprocesses stop, redirect logs to Docker).
* Update various tool versions.
* Upgrade SWIFT to 5.8, upgrade LIBBOOST to 1.82, and remove legacy support of Ubuntu 20.04 LTS.

## 2023.05

* Improved Docker container build infrastructure (using existing variables throughout the scripts) and reduced the number of layers by copying a skeleton.
* Added environment variable `IIC_OSIC_TOOLS_VERSION` so that user scripts can check container version.
* Added `gnuplot`, `FasterCap`, `FastHenry2`, and `openEMS`.
* Allow custom container names in `eda_server` scripts.
* Add a dedicated startup script for Jupyter notebooks called `start_jupyter.bat`.
* Update various tool versions.

## 2023.04

* Fix crashes of `OpenLane` and `OpenLane2`.
* Update various tool versions.
* Specify custom DNS in server scripts (see `eda_server_conf.sh`).
* Add a dedicated startup script for Jupyter notebooks called `start_jupyter.sh`.

## 2023.03

* Add newly released `OpenLane2` flow.
* Add IHP `SG13G2` 130nm SiGe:C BiCMOS open-source PDK.
* Add `firefox` (again).
* Add `openram`.
* Add more examples into `/foss/examples`.
* Improve EDA server scripts (`eda_server_start.sh`, `eda_server_restart.sh`, `eda_server_stop.sh`).
* Update various tool versions.

## 2023.02

* Fix noiseless SKY130 resistors (`ngspice-39` plus setting a proper flag in `.spiceinit`).
* Harmonize shell script text (using [INFO] and [ERROR] like in other scripts).
* Improve the IIC-PEX script.
* Fix the `klayout` error message ".lyp not found".
* Update various tool versions.

## 2023.01

* Added packages: `fusesoc`, `jupyterlab`, `edalize`, `surf` (browser).
* Added support to run images for multiple users and implemented scripts for starting and stopping multiple instances.
* Removed packages: `firefox`
* Update base OS (Ubuntu) to 22.04 LTS.
* Update various tool versions.
* Fix screen lockup (timeout due to `light-greeter`) in VNC mode.
