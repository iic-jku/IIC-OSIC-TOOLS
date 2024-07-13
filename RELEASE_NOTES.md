# IIC-OSIC-TOOLS Release Notes

This document summarizes the most important changes of the individual releases of the `IIC-OSIC-TOOLS` Docker container.

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
