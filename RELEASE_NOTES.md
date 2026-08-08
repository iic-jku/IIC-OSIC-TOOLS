# IIC-OSIC-TOOLS Release Notes

This document summarizes the most important changes of the individual releases of the `IIC-OSIC-TOOLS` Docker container.

## 2026.08

* [Adding] `sak-gds-xor.py` to XOR two layouts (GDS2/OASIS) with KLayout and write the differing geometry to an output layout, for comparing two revisions of a layout or a signoff database against its source.
* [Adding] the `unifont` package, so schematics, netlists and terminal output containing unicode symbols render instead of showing boxes.
* [Adding] a complete logo asset pack in `_logo/` (PNG and SVG, color/mono/reversed, horizontal and stacked), which is now used for the project branding described below.
* [Update] VACASK support for the IHP `SG13CMOS5L` PDK is completed. The CMOS5L-own models are discovered instead of hardcoded, which picks up `cornerCAP`/`cornerDIO`/`cornerPNP`, compiles the CMOS5L-own Verilog-A to OSDI, and survives the upstream MoM capacitor renames (`cap_mfringe` → `cap_mom` → `cap_cmomi`) that broke the image build. The 80 CMOS5L-own `xschem` symbols and the CMOS5L `xschemrc` now also get the VACASK glue (`spectre_format=` lines, VACASK section, CMOS5L corner set), so devices such as `cap_cmomi` can be netlisted for VACASK from `xschem`. The glue is temporary and will be dropped once VACASK supports `ihp-sg13cmos5l` upstream.
* [Update] `xschem` bumped past the upstream fix for the headless `tcleval` focus call ([xschem issue #494](https://github.com/StefanSchippers/xschem/issues/494)); the local patch guarding that call is removed again.
* [Update] the Yosys stack (`yosys`, `eqy`, `sby`, `mcy`) is held back at `v0.67`. Yosys `v0.68` removed the `-fast` option of the `abc` pass, which LibreLane's `pyosys` synthesis script calls unconditionally, so every LibreLane flow would die in synthesis. The pin is lifted once LibreLane upstream stops calling it.
* [Update] various tool and Python package version bumps: `bender`, `ghdl`, `iverilog`, `kepler-formal`, KLayout (`v0.30.10`), Magic (`8.3.680`), `nextpnr`, `nvc` (`r1.22.1`), `open_pdks`, `openEMS`, OpenROAD, `palace`, `slang` and the `slang-yosys-plugin`, `spike`, `uv` (`0.12.2`), VACASK, `verible`, and `xschem`.
* [Changing] the browser (noVNC) session now uses the full noVNC client instead of the stripped-down `vnc_lite.html` demo page that had been served from `/` since the container's ConSol ancestry. The control bar this adds provides clipboard transfer in both directions, fullscreen, ctrl-alt-del, and connection settings — none of which the lite client has. The advertised URL is unchanged (`http://localhost:<WEBSERVER_PORT>/?password=<pw>` still connects straight through), and the container desktop now resizes to the browser window by default; the "Scaling Mode" setting overrides that and is remembered.
* [Changing] the project branding is refreshed with the new logo: the `README` header, the noVNC favicon and browser-tab title, the JupyterLab favicons (including the inverted "busy" variants, so the kernel-activity cue is kept), and the desktop background, which is now scaled rather than centered and therefore no longer cropped on narrow screens. The desktop backdrop color is set to `#22272E` — the color configured until now was in a format `xfdesktop` 4.18 ignores, so the desktop always fell back to the stock blue.
* [Changing] the desktop terminal is `xfce4-terminal` instead of `gnome-terminal`, which is what the right-click menu, the panel launcher, `Ctrl+Alt+T` and Thunar's "Open Terminal Here" now open. `gnome-terminal`'s D-Bus-activated factory frequently failed to map a window inside the container, leaving 10x10 leader windows, accumulating `gnome-terminal --wait` processes, and the XFCE error dialog "Failed to execute default Terminal Emulator / Input/output error". `gnome-terminal` is purged; `xterm` is deliberately kept, because `xschem` spawns it for simulations.
* [Changing] `xschem` now requires the Ctrl key for zooming and panning inside graph (waveform) widgets (`graph_use_ctrl_key`), so the mouse wheel keeps zooming the schematic when the pointer happens to be over a graph. The setting is applied centrally in the system-wide `xschemrc` and is therefore active for all PDKs; the `Options` menu toggle can still switch it back per session.
* [Changing] `Veryl` now works out of the box: `verylup setup` runs at image build time, so `veryl` and `veryl-ls` are on `PATH` and the default toolchain is preinstalled, while the toolchain tree stays user-writable for `verylup install`/`pin` at runtime. Previously `verylup setup` failed for non-root users with `EPERM`. The `XDG_DATA_HOME=/headless/.data-default` override is dropped along with it, so build time and runtime resolve the same spec-default path (`~/.local/share`).
* [Changing] the container startup was audited across all three operating modes: `start_shell.sh` defaults `DISPLAY` to the host gateway on macOS and to the host `DISPLAY` on Linux instead of a dead `:0`; the VNC session no longer starts `ssh-agent`, `gpg-agent`, `xiccd`, `tumblerd` or the `udisks2` GVfs volume monitor, none of which are useful in the container; `~/.Xauthority` is pre-created; the X11-mode terminal runs under `dbus-run-session` so `xfconfd` works; and known-harmless noVNC/GTK/dbus messages are filtered out of the container log.
* [Changing] `PyOPUS` is ported from PyQt5 to PySide6. Its threaded plotting (`pyopus.plotter`, used by the plotting demos) works unchanged; the `pyog` project GUI is removed, as its table models rely on PyQt5-specific virtual dispatch.
* [Changing] the Liberty files in `libs.ref` of all packaged PDKs are now also provided gzipped as `.lib.gz`, and the `librelane`/`openlane`/`qflow` configurations shipped with the PDKs reference the compressed files. All Liberty-reading tools in the image (`yosys`/ABC, OpenROAD, OpenSTA, `librelane`, `kepler-formal`) handle `.lib.gz` transparently. **Deprecation notice:** the uncompressed `.lib` files are kept alongside for the next few releases and will then be removed, so please migrate your own flows and configurations to the `.lib.gz` paths. The SPICE model libraries in `libs.tech/{ngspice,xyce,vacask,qucs-s}`, which also use the `.lib` extension, are not affected and stay uncompressed.
* [Fix] the PDK operating-point annotation symbols (`annotate_fet_params.sym`, `annotate_bip_params.sym`) showed `NaN` in every field in `2026.07`, affecting IHP `display_fet_params`/`display_bip_params` and sky130 `sky130_display_fet_params`. An upstream reentrancy guard in `translate()` was held across the Tcl evaluation, so a `tcleval(...)` callback that itself calls `xschem translate` — which is exactly what these annotators do — got an empty string back, losing the model name. `xschem` is bumped past `f583f470`, which releases the guard before the Tcl evaluation and keeps it only around the token parsing (see [issue #342](https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/342) and [xschem issue #460](https://codeberg.org/stef_xschem/xschem/issues/460)).
* [Fix] `xschem` no longer asks whether embedded Tcl scripts may be executed (`xschem_execute_scripts yes` in the shipped user `xschemrc`), which the PDK launcher symbols and `tcleval()` attributes need in order to work silently.
* [Fix] `start_vnc.sh` now detects rootless Podman on macOS and Windows as well. The detection was gated on Linux, but the Podman machine VM is rootless by default too and its `rootlessport` helper refuses to publish host ports below 1024, so `WEBSERVER_PORT` stayed at `80` and container creation failed with "rootlessport cannot expose privileged port 80"; it now auto-selects `8080` there as well (`--userns=keep-id` stays Linux-only). A failed container start also reports the error and exits non-zero instead of still printing the VNC URL.
* [Fix] the `[INFO] noVNC HTML client started` line printed by the container omitted the web server port, which is misleading whenever `WEBSERVER_PORT` is not `80` — that is, by default under rootless Podman, including on macOS and Windows. The `README` instructions had the same omission.
* [Fix] `XDG_RUNTIME_DIR` is created per user at container startup as `/tmp/runtime-<uid>` with mode `0700`, instead of the shipped root-owned, world-writable `/tmp/runtime-default` shared by every UID. That violated the XDG specification, which `dbus-daemon` and others verify — dbus warned and disabled its transient service directory. An externally provided `XDG_RUNTIME_DIR` (for example WSLg's) is respected, `CONTAINER_XDG_RUNTIME_DIR` still overrides explicitly, and `start_x.sh` mounts a forwarded Wayland socket at the neutral path `/tmp/host-wayland`, which the profile script links into the per-user directory.
* [Fix] `PySide6` was left broken by the removal of `PySide6-Addons`: both wheels ship the shared top-level `PySide6` files and `pip` does no cross-package reference counting, so uninstalling Addons deleted the `PySide6/__init__.py` that Essentials still needs. `PySide6` then imported as a namespace package without `__version__`, breaking matplotlib's Qt backend and every GUI on top of it, including `chipify` and `snp2le`. `PySide6-Essentials` is now force-reinstalled at the already resolved version, so it cannot pull a version mismatching the installed `shiboken6`.
* [Fix] `charlib` and `cir2py` are installed as wrappers that unset `PYTHONPATH` before launching their venv entry points, so the container-wide Python path no longer shadows CharLib's pinned `PySpice` fork; binaries from Python virtualenvs are no longer symlinked into `$TOOLS/bin`.
* [Fix] the `feed` parameter of the IHP `SG13CMOS5L` `cap_cmomi` MoM capacitor can be set again in VACASK. The ngspice model writes the default symbolically (`.param none=0 same=1 double=2`, then `feed=double`) and the model conversion carried that over verbatim; VACASK treats a subckt parameter whose default references another parameter as derived and rejects every override with `Parameter 'feed' not found.`. That silently locked the device to `feed=double` and broke the `xschem` → VACASK path outright, since the `spectre_format=` line always emits `feed=<token>`. `install_ihp_cmos5l.sh` now resolves file-level symbolic constants into the subckt defaults after conversion, and new regression test 29 covers `cap_cmomi` in both ngspice and VACASK against the capacitance the KLayout PCell prints in its own `C=` label.
* [Fix] selecting the PDK at container start (`-e PDK=<pdk>`) now also selects the matching standard cell library. `STD_CELL_LIBRARY` was hardcoded to `sg13g2_stdcell` in the profile script, so every PDK other than `ihp-sg13g2` — `ihp-sg13cmos5l`, `sky130A`/`B`, `gf180mcuC`/`D` — silently kept pointing at the IHP `SG13G2` cells; `GF_PDK_OPTION` was likewise left unset for `gf180mcu`, where KLayout then warns and assumes `D`. Both are now derived from `$PDK` using the same mapping `sak-pdk-script.sh` applies when switching the PDK of a running session, and an explicitly provided value still wins, so a custom or unpackaged library can be selected as before.
* [Fix] the KLayout PCell libraries of both IHP PDKs no longer break when two KLayout processes run at the same time. The libraries preprocess every PCell module into `$TMPDIR/<module>_pre.py` and delete it again, using the bare module name — and `SG13G2` and `SG13CMOS5L` ship the same module names (`rfnmos_code`, `bondpad_code`, …). On the shared `/tmp` two concurrent processes therefore wrote and deleted the *same* file, and the loser died with `FileNotFoundError` while importing it. Since that exception escapes the library constructor called from `autorun.lym`, the PDK registered *no* PCell at all, not just a broken one — two KLayout windows, or an LVS/DRC job next to an interactive session, were enough. Ten concurrent loads reproduced it reliably; the file now carries the process ID and its removal tolerates a file that is already gone. Regression test 27 additionally gives each PDK run its own `TMPDIR`.
* [Fix] the `gf180mcuD` `efuse` PCell produces geometry instead of an empty cell. Two upstream bugs: `draw_efuse()` was called without its required `device_name` argument (unused in the body), and it read `efuse.gds` from `/home/$USER/.klayout/pymacros/cells/efuse`, where nothing ever installs it — the GDS ships next to the module. Both cell libraries are patched at PDK-install time.
* [Fix] instantiating IHP PCells no longer floods the console. `sealring` obtained the PDK version by shelling out to `git` inside the PDK tree, which carries no `.git`, so every instantiation printed `fatal: not a git repository` and labelled the seal ring `PDK version: Unknown`; it now reads the `COMMIT` file the installer writes next to the PDK. `isolbox` defaulted its length and width to `3u` while its own callback clamps both to `3.6u`, warning on every default instantiation; the tech parameter is corrected (the neighbouring area and perimeter defaults already assumed `3.6u`, and the geometry is unchanged). The ~35 `Box.destroy: already destroyed!` warnings per run — the CNI foreground booleans consume their operands and several PCells destroy them again, which is a no-op — are demoted to a verbosity-gated level.
* [Fix] `sak-pin-reorder.py` matches the `.subckt` card case-insensitively. SPICE cards are case-insensitive and netlisters disagree — `xschem` and Magic write `.subckt`, KLayout-PEX writes `.SUBCKT` — so every `kpex`-extracted netlist failed with "No .subckt line found in the netlist file". The spelling found in the source file is carried through to the rewritten header.
* [Build] moved the build-only compiler toolchains (`clang`/LLVM, `gnat`, `gfortran`) from the runtime image to `base-dev`, and dropped the unused `ant` and `binutils-gold`; the runtime image keeps GCC, `mold`, and only the matching shared libraries (`libllvm18`, `libgnat-13`), which reduces the image by about 300 MB.
* [Build] consolidated the Python Qt bindings on `PySide6`, saving about 115 MB. `python3-pyqt5` and `python3-pyqt6` are gone from the runtime image (PyQt5 stays in `base-dev`, where the PyOPUS build needs it), the Qt libraries they used to drag in are now requested explicitly, and the unused `libqt5xmlpatterns5`, `libqt5multimedia5`, `libqt6charts6` and `linguist-qt6` are dropped. `PySide6` additionally loses its Qt translations and QML modules. The Qt5 and Qt6 runtimes themselves both stay, because OpenROAD's GUI is Qt5-only while KLayout, Kactus2 and Qucs-S are Qt6.
* [Build] no `pip` download cache reaches the image anymore. `PIP_NO_CACHE_DIR` is exported, because the `--no-cache-dir` flag only covers the outer `pip` and is not handed down to the nested `pip` that PEP 517 build isolation runs, which left about 55 MB of download residue; the cache directory is removed afterwards as well. The leftover `rustup` directory is now cleaned up at the end of the EDA install, since later build steps re-created it.
* [Build] audited and resolved every `FIXME` in the build scripts and the ORFS test: the obsolete `GDS_ALLOW_EMPTY` export is dropped from the `ihp-sg13g2` ORFS test, the `rftoolkit` pins are confirmed against upstream `HEAD` and `LinAlgebra` is cloned blob-filtered, the `gobject-introspection` and `LibMan` patches document the exact condition for dropping them and now fail loudly when upstream moves, the `sky130A` KLayout tech-file repairs are guarded so the build reports when `open_pdks` no longer needs them, and the OpenMPI note is marked as a permanent container constraint rather than a defect.
* [Build] extended the Python regression tests: `PySide6` is checked for a valid `__version__`, importable `chipify`/`snp2le` Qt entry points, and complete on-disk files against the installed wheel `RECORD` metadata; the CharLib test verifies the `PySpice` API actually used and that `charlib` on `PATH` is the wrapper script.
* [Docs] normalized the project name to `IIC-OSIC-TOOLS` throughout the documentation and the install scripts.

## 2026.07

* [Adding] full [Podman](https://podman.io/) support across all start and install scripts: the container engine is auto-detected (`CONTAINER_ENGINE`), rootless mode adds `--userns=keep-id` and defaults the VNC webserver to port `8080`, and a `DOCKER_REGISTRY` variable qualifies the image name. No `podman-docker` alias or script edits are needed anymore.
* [Adding] `chipify` GUI/CLI wrapper for mismatch simulation, parameter sweeps, and yield analysis with `xschem`/`ngspice`.
* [Adding] `snp2le` to convert Touchstone S-parameter files into lumped-element netlists for `ngspice` and `vacask`.
* [Adding] VACASK setup for the IHP `SG13CMOS5L` PDK.
* [Adding] regression/smoke tests for analog circuit design, SPARX, KLayout PCells, TinyWhisper (`ihp-sg13g2`), and the `sak-drc.sh`/`sak-lvs.sh`/`sak-pex.sh` scripts.
* [Adding] `sak-pin-reorder.py` to reorder (X)SPICE `.subckt` pins to match an Xschem symbol.
* [Update] major rework of `sak-drc.sh`, `sak-lvs.sh`, and `sak-pex.sh`: KLayout DRC/LVS for all PDKs (`sky130A`, `gf180mcuD`, `ihp-sg13g2`, `ihp-sg13cmos5l`), new `gf180mcuD` DRC, gzipped and `.klay.gds` layout support, and robust workdir handling.
* [Update] `gdsfill` switched to the Rust implementation; `gf180mcu` PDK now installed via `ciel`.
* [Update] `yosys` and `slang-yosys-plugin` switched to the CMake build; `gmsh` now available on `arm64`.
* [Update] various tool and Python package version bumps (Magic, open_pdks, VACASK, iverilog, OpenROAD, and others).
* [Fix] `surfer` crash (`GLXBadFBConfig` panic) and blank window on macOS in X11 mode (XQuartz): a wrapper now forces the EGL rendering path and disables MIT-SHM presentation on TCP X connections; obsolete `surfer` alias removed.
* [Fix] broken `ngspice` mixed-signal (VHDL co-simulation) support (issue #287).
* [Fix] stale Xauth file in the VM; `libman` library loading (`capnp` libs and RPATH); moved IHP stdcell `xschem` symbols.
* [Fix] IHP `sg13g2_io` SPICE netlist name for `sg13g2tovc` (provide a `sg13g2_io.spi` compatibility symlink).
* [Fix] `xschem` parallel build race in the Makefile and headless `tcleval` focus call.
* [Fix] KLayout pcell activation for `sky130A`/`gf180mcuD` when the container `PDK` variable would otherwise fail (fall back to the generic `gdsfactory` PDK); set `GF_PDK_OPTION` for `gf180mcuC`/`gf180mcuD` to suppress the ambiguous-PDK warning.
* [Remove] the dedicated `gdsfactory` virtual environments for sky130/gf180mcu: both pcell libraries are now patched at PDK-install time to run on the current system `gdsfactory` (issue #162).
* [Build] significant image size reductions: slim the runtime LLVM, strip static libraries from `xyce`/`palace`/`openroad`, remove the unused `PySide6-Addons` (QtWebEngine/Qt3D, ~410 MB), deduplicate Python packages and the PDK copy, drop bundled test suites, remove the auto-downloaded Rust toolchain, and install only Java 17.
* [Build] use GitHub mirrors for RISC-V submodule fetches; rename `tool_pip.sh` to `tool_eda.sh` and add `check_eda_tool_version.py` (also handles Cargo/Gem tools, and now prerelease versions).
* [Build] switch `buildx bake` to a DAG-based `all` target and remove the obsolete disabled `xyce-xdm` image.
* [Build] harden and speed up the regression test harness: smarter test scheduling, improved Docker test output and failure handling, and colored pass/fail output.
* [Docs] rewrite the Podman sections in `README.md`/`KNOWN_ISSUES.md` and add a macOS X11-vs-VNC performance note.

## 2026.06

* [Adding] interactive install scripts (`install.sh`, `install.bat`, `install.ps1`) that set up the prerequisites; installer logic moved to `install.ps1` and license header/disclaimer added.
* [Adding] `eda_server_bkdatadir.sh` backup script and `eda_server_rmdatadir.sh` script for managing the EDA server data directory.
* [Adding] KLayout netlist import plugin.
* [Adding] `run_palace` and `combine_snp` wrapper scripts for the `gds2palace` EM workflow.
* [Adding] `DOCKER_EXTRA_PARAMS` can now be passed in from outside the start scripts.
* [Adding] `test_ams_chip_sg13g2.sh` regression test (with option to suppress ngspice/xschem plots).
* [Update] X11 forwarding behavior; start scripts no longer abort on missing X and set the keyboard for VNC.
* [Update] various tool versions and Python package versions.
* [Fix] `gf180mcuD` access rights for KLayout macros.
* [Fix] harden startup scripts: robust container stop/remove, error checks for `docker pull`/`run`, safer permission handling, hardened `nss_wrapper` user generation, and improved X11 socket/xauth/xhost cleanup.
* [Fix] read interactive user input from `/dev/tty` (and use fd 3) instead of `stdin`.
* [Remove] `klive` from the KLayout install packages.
* [Docs] updated `KNOWN_ISSUES.md` ("Xschem Library Path"), `README.md` ("Installed PDKs"), and `TESTS.md`.

## 2026.05

* [Adding] `XKB_KEYBOARD_LAYOUT` and `XKB_KEYBOARD_VARIANT` environmental variables for `start_vnc.sh`/`start_vnc.bat` to set the keyboard layout inside the VNC session (`setxkbmap` is called in `ui_startup.sh`).
* [Update] Refactor `install_klayout.sh` to use the KLayout package manager; harmonized KLayout package list in the README.
* [Update] `sak-pex.sh` updated based on input from Tim Edwards.
* [Update] `sak-pdk` sets `KLAYOUT_PATH` only once and quotes the PDK name when sourcing `sak-pdk-script.sh`.
* [Update] VACASK commit and `sg13g2tovc` flag to fix issue #279.
* [Update] Various tool versions.
* [Fix] sky130A KLayout pcells patched to use `gf.boolean operation="-"` instead of the deprecated `"A-B"`.
* [Fix] KLayout permissions for macros (quick fix for issue #273).
* [Remove] Compact `ngspice` model generation.
* [Remove] Revert "KLayout: turn on 3x oversampling" (caused issues on some setups).
* [Build] Remove inline auto-taper patch from tool install script.

## 2026.04

* [Adding] `kepler-formal` tool for OpenROAD logic equivalence checking (LEC) support.
* [Adding] support for the IHP `SG13CMOS5L` PDK (PDK is WIP, some parts might not work correctly yet).
* [Adding] `cocotbext-ams` for mixed-signal co-simulation with `cocotb`.
* [Adding] KLayout Vector File Export plugin and CLI.
* [Adding] VACASK configuration (`.vacaskrc`) and setup for IHP SG13G2.
* [Adding] `svck` customizable SystemVerilog linter (with `verible`).
* [Adding] VNC browser access info line with auto-login URL to `start_vnc.sh` and `start_vnc.bat`.
* [Adding] `uv` Python package manager to the container image.
* [Adding] `gdsfill` Python package for dummy metal fill insertion.
* [Adding] `git-lfs` to the base container image.
* [Update] `slang-yosys-plugin` and `ghdl-yosys` plugins are moved into `/foss/tools`.
* [Update] LibreLane to 3.0.0.
* [Update] KLayout default settings: crosshair cursor, hidden empty layers, visible layer numbers, thicker DRC/LVS markers (yellow), manhattan connection mode, 3x oversampling, 10nm default grid, 4-space macro indent.
* [Update] SAK scripts (`sak-drc.sh`, `sak-pex.sh`, `sak-lvs.sh`) updated.
* [Update] gdsfactory strategy: gdsfactory 9 for `gf180mcuD`, gdsfactory 8 venv for `sky130A`.
* [Update] various tool versions.
* [Fix] KLayout netlist import for `ihp-sg13g2`: make `m=` optional and support `nf=` for MOSFET finger count.
* [Fix] AppCSXCAD GLX context failure via wrapper script (issue #254).
* [Fix] KLayout pcells for `sky130A` and `gf180mcuD` (gdsfactory version compatibility).
* [Fix] KLayout `ERROR: no PDK info found for tech` for `sky130A` and `gf180mcuD`: the pcell activation shim now falls back to the generic gdsfactory PDK on any failure (the container's ever-present `PDK` env var poisons `CONF.pdk`, so `get_active_pdk()` raises `ModuleNotFoundError`, not the `ValueError` the shim previously caught).
* [Fix] VACASK OSDI models using AVX-512 instructions (restrict to x86-64-v2).
* [Fix] non-root/rootless setup: add Podman detection and `XDG_RUNTIME_DIR` fallback in `start_x.sh`.
* [Fix] `gf180mcuD` transistor OP annotation in `xschem` symbol files.
* [Fix] prevent JSON injection in startup scripts using `jq --arg`.
* [Fix] path quoting and `PYTHONPATH`/library directory setup in profile scripts.
* [Docs] add X11 authorization failure (xauthority directory) to `KNOWN_ISSUES.md`.
* [Build] Added `build-target.sh` script to easily build individual tool targets.
* [Build] Improved version-check tools; removed `tools_lib`.
* [Build] Comprehensive hardening of install scripts: strict error handling (`set -e`), proper variable quoting, and failure checks across all tool build scripts.
* [Build] Added `SOURCES` file to every tool install, recording the tool name and commit hash for traceability.
* [Build] Added devcontainer build script and updated devcontainer image.
* [Build] Added parameter to control caching behaviour in build scripts.
* [Build] Added SPDX license headers and bumped copyright years to 2026.
* [Build] Moved compile-time-only tools from `base` to `base-dev` image.
* [Build] Tcl_Size compatibility shim for Tcl 8.6 and OpenROAD build fixes.
* [Build] OR-Tools and Boost build dependency fixes.

## 2026.02

* [Adding] `spicebind` tool for SPICE simulator bindings in digital simulators.
* [Adding] `gds2palace` and `setupEM` for EM simulation workflow (`x86_64` only for now).
* [Adding] `libjson-glib` as new dependency for `gtkwave`.
* [Update] `openvaf` with `llvm18` feature enabled.
* [Update] various tool versions (OpenEMS, OpenROAD, Palace, GHDL, xschem, and others).
* [Re-Adding] `pyopus` circuit optimization framework.
* [Remove] `ElmerFEM`.

## 2025.12

* [Adding] custom bindkeys for Magic for IHP SG13G2 PDK.
* [Adding] the `EDA_IMAGE_TAG` variable to `eda_server_conf.sh` and adds a new `-t` option to `eda_server_start.sh` and `eda_server_restart.sh` for specifying the Docker image tag.
* [Update] various tool versions.
* [Update] LLVM/Clang to version 18.
* [Fix] RC-extraction issue in `sak-pex.sh`.
* [Remove] custom build of `bottleneck`.

## 2025.11

* [Build] Split `base` image into `base` and `base-dev` so that all `*-dev` packages do not bloat the final image. This reduces the image size considerably.
* [Build] Switch IHP PDK from IHP repo and `dev` branch to IIC-owned repo so that we can merge required fixes directly.
* [Build] Files and directories copied from the `skel` into the image get repaired permissions and owner at build time.
* `openroad` and `sta` are now relatively new versions, while the older versions required by LibreLane are available as `openroad-librelane` and `sta-librelane`. A `librelane` wrapper takes care to point to the correct versions when `librelane` is used.
* Improved `sak-pdk.sh` script to dump all set vars.
* [Adding] several KLayout add-on packages for layer selection keybindings, auto-save of layouts, quick align function, quick move function, library manager, and more.
* [Adding] Python formatter `black`.
* [Adding] AWS `palace` 3D EM simulator.
* [Adding] `gmsh` 3D masher.
* [Re-adding] `pyuvm`.
* [Fix] `ngspice` co-simulation fail with VHDL.
* [Update] various tool versions.
* [Remove] various packages related to Qt5, and switch to Qt6 where possible.

## 2025.09

* Improve various aspects of the image build process (many small things), reduce Docker layers.
* Support Distrobox and Podman (check the `README.md`).
* Store IHP PDK GitHub commit hash in the image (see `KNOWN_ISSUES.md`).
* Make startup scripts more robust.
* Add an FPGA toolchain (`nextpnr` for the Lattice iCE40 series) for prototyping.
* Add several productivity improvements to `klayout`.
* Update various tool versions.
* Update DRC/LVS/PEX scripts to latest IHP versions.
* Remove `vscode`, mainly for size reasons.
* Remove (temporarily) `pyuvm`, as not compatible with `cocotb` 2.0.

## 2025.07

* Complete overhaul of image build scripts: We now use a multistage build using a local registry and individual tool images to speed up the build process.
* (Re-)adding `openems`.
* (Re-)adding `fault`.
* (Re-)adding `hdl21` and `vlsirtools`.
* Adding `librelane` (and removing `openlane`).
* Adding `kactus2`.
* Adding `najaeda`.
* Adding `verylup` (so users can install `veryl`).
* Adding `vacask`, a modern analog circuit simulator.
* Adding support for Docker Desktop on Linux in `start_x.sh`.
* Adding support of `gf180mcuD` in the `sak-drc.sh`, `sak-lvs.sh`, and `sak-pex.sh` scripts.
* Adding `charlib` for characterization of standard cells.
* Adding analog inverter example for `gf180mcuD`.
* Adding SBT for Chisel.
* Switching from `volare` to `ciel` for PDK management.
* Switching from `openvaf` to `openvaf-reloaded`.
* `librelane` is now supported for `ihp-sg3g2`.
* Update various tool versions.
* Reduce image size by removing the measurement folder from the IHP PDK, optimizing RISC-V libraries, and a few compile optimizations.
* Remove (temporarily) `klayout-pex` due to incompatibility with some dependencies.
* Remove `gf180mcuC` technology flavor to decrease image size.
* Remove (temporarily) `openram` (re-add later when PyPi package is updated).
* Remove `svase` and `morty` from the PULP tools.

## 2025.05

* **ATTENTION**: The default PDK has been switched to `ihp-sg13g2` (from `sky130A`).
* Startup scripts now feature a quiet mode when `IIC_OSIC_TOOLS_QUIET` is set.
* Bump various tool versions.
* Using local `openlane` build for bugfix and resolution of version clash.
* Enable build of `libvvp` in `iverilog`.
* Enable build of Qtbindings in `klayout`.
* Rename scripts beginning with `iic-` to `sak-` (and install alias to still allow use of `iic-`).
* [Maintenance] The important scripts from `osic-multitool` are now part of `iic-osic-tools` to make maintenance easier.
* [Maintenance] The handling of `rust` and `cargo` have been streamlined.
* Removed the contents of the `sak` folder from the image.

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
