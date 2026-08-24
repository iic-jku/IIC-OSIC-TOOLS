# IIC-OSIC-TOOLS Release Notes

This document summarizes the most important changes of the individual releases of the `IIC-OSIC-TOOLS` Docker container.

## 2026.08

* [Adding] [`gdscheck`](https://github.com/aesc-silicon/gdscheck) `v0.1.2`, a DRC engine for GDSII layouts written in Rust. It reads GDS directly, flattens the cell tree itself and needs neither KLayout nor Magic nor a foundry toolchain; rules are plain YAML decks, the checks fan out across all cores, and violations are written as a KLayout-compatible `.lyrdb` marker database that loads straight into the marker browser. The decks for IHP `SG13G2` and `SG13CMOS5L` ship inside the binary, so `gdscheck run --process ihp-sg13g2 ...` works without any external files. Note that upstream calls it experimental with incomplete coverage, so cross-check against Magic or KLayout before signoff.
* [Adding] FPGA place-and-route for Lattice ECP5 next to the existing Lattice iCE40 flow: `nextpnr` is now built for both architectures in one pass, and [`prjtrellis`](https://github.com/YosysHQ/prjtrellis) supplies `ecppack` and the ECP5 database. This completes the in-container build chain for the ULX3S board of the AMS template's FPGA flow, at a cost of roughly 95 MB (the ECP5 part of the Trellis database dominates, and the unused MachXO families are dropped at install time). Programming the board stays on the host, since the container has no USB access. New test 33 takes an iCE40 and an ECP5 blinky through synthesis, place-and-route and bitstream packing.
* [Adding] `sak-gds-xor.py`, which XORs two layouts (GDS2/OASIS) with KLayout and writes the differing geometry out, for diffing two revisions or a signoff database against its source.
* [Adding] `sak-open`, a launcher that scans a design tree and puts up one button per design file, grouped by directory, each opening the right tool (`xschem`, KLayout, Magic, GTKWave, `gaw`, editor) in the file's own directory. The tree is rescanned periodically, the list filters by type and name, and the right mouse button offers a terminal there or the path on the clipboard.
* [Adding] `sak-render.py`, which renders a layout to PNG off-screen with the PDK's own KLayout colors and stipples, cropped to the geometry, on white and/or black. All four packaged technologies work through `-t`; `-l`/`-x` select layers by group, name or `layer/datatype` (`-l +filler` for the classic chip shot), and `--list` prints what a technology offers.
* [Adding] the `unifont` package, so unicode symbols in schematics, netlists and terminal output render instead of showing boxes.
* [Adding] a complete logo asset pack in `_logo/` (PNG and SVG, color/mono/reversed, horizontal and stacked), used for the branding refresh below.
* [Update] `sak-drc.sh` runs `gdscheck` as a third DRC engine through the new `-g` flag, next to Magic (`-m`) and KLayout (`-k`). The `-l` levels map onto the suites built into the binary (`precheck` to `precheck`, `macro` to `core`, `regular` to `main`), and `-s` selects a suite directly, which also reaches the `density` and `antenna` suites. The `.lyrdb` report and log land in `<cell>.gdscheck.drc/` beside the Magic and KLayout run folders, and unlike the bare binary, which always exits 0, the wrapper turns violations into a non-zero exit code, so Makefile targets can gate on it.
* [Update] VACASK support for IHP `SG13CMOS5L` is complete, and the conversion now comes from upstream's own `sg13cmos5ltovc.py` ([VACASK issue #94](https://codeberg.org/arpadbuermen/VACASK/issues/94)), which also converts CMOS5L's own standard-cell and I/O netlists instead of pointing those includes at `ihp-sg13g2`. Three defects found in it were fixed upstream, so no local fixups remain; the only local addition left is the `xschem` menu listing of the `cornerDIO` and `cornerPNP` sections, which upstream omits.
* [Update] `xschem` bumped past the upstream fix for the headless `tcleval` focus call ([xschem issue #494](https://github.com/StefanSchippers/xschem/issues/494)); the local patch is removed again.
* [Update] `LibMan` bumped past the upstream Qt6 build fix ([LibMan issue #5](https://github.com/IHP-GmbH/LibMan/issues/5)); the local patch is removed again.
* [Update] the Yosys stack (`yosys`, `eqy`, `sby`, `mcy`) is held back at `v0.67`: `v0.68` removed the `abc` pass's `-fast` option, which LibreLane calls unconditionally, so every flow would die in synthesis. The pin lifts once LibreLane stops calling it.
* [Update] various tool and Python package version bumps: `bender`, `ghdl`, `iverilog`, `kepler-formal`, KLayout (`v0.30.10`), Magic (`8.3.680`), `nextpnr`, `nvc` (`r1.22.1`), `open_pdks`, `openEMS`, OpenROAD, `palace`, SiliconCompiler, `slang` and the `slang-yosys-plugin`, `spike`, `uv` (`0.12.2`), VACASK, `verible`, and `xschem`.
* [Changing] the browser (noVNC) session uses the full noVNC client instead of the `vnc_lite.html` demo page served from `/` since the container's ConSol ancestry, which adds clipboard transfer in both directions, fullscreen, ctrl-alt-del and connection settings. The advertised URL is unchanged, and the desktop now resizes to the browser window by default.
* [Changing] noVNC comes from upstream `v1.7.0` instead of Ubuntu's `1.3.0` from 2021, which carries the stuck-button defect below. Behavior is configured through the `defaults.json`/`mandatory.json` files added in `1.6.0` rather than injected query parameters, and the connection target is pinned to the address the page was loaded from, so a stale host/port cannot win over the port in use.
* [Changing] the branding is refreshed with the new logo: `README` header, noVNC favicon and tab title, JupyterLab favicons (the inverted "busy" variants included), and the desktop background, now scaled rather than centered so it is no longer cropped on narrow screens. The backdrop color `#22272E` finally applies; the value configured until now was in a format `xfdesktop` 4.18 ignores.
* [Changing] the desktop terminal is `xfce4-terminal` instead of `gnome-terminal`, whose D-Bus-activated factory frequently failed to map a window inside the container, leaving 10x10 leader windows, stray `--wait` processes and an XFCE "Input/output error" dialog. `gnome-terminal` is purged; `xterm` stays, because `xschem` spawns it for simulations.
* [Changing] double-clicking a file in Thunar (or handing it to `xdg-open`) opens the matching tool: a system-wide `mimeapps.list` and expanded MIME definitions route schematics, layouts, `.mag`, `.cdl`, netlists, waveforms and Makefiles to their viewers, with new desktop entries for GTKWave and `gaw` and an own MIME type for ngspice `.raw` (upstream that extension is a camera raw format). An audit of ~90 extensions found 21 without a handler, 15 of which are now mapped; `ristretto` and `zathura` are installed, and new test 30 checks the extension → MIME type → application chain.
* [Changing] `xschem` requires the Ctrl key to zoom and pan inside graph (waveform) widgets (`graph_use_ctrl_key`), so the wheel keeps zooming the schematic when the pointer is over a graph. Set system-wide, so it holds for all PDKs; the `Options` toggle still switches it back per session.
* [Changing] `Veryl` works out of the box: `verylup setup` runs at build time, so `veryl` and `veryl-ls` are on `PATH` with the default toolchain preinstalled and the tree stays writable for `verylup install`/`pin`. It previously failed for non-root users with `EPERM`. The `XDG_DATA_HOME` override is dropped with it.
* [Changing] the container startup was audited across all three operating modes: `DISPLAY` now defaults sensibly per host OS instead of a dead `:0`; the VNC session no longer starts `ssh-agent`, `gpg-agent`, `xiccd` or the `udisks2` volume monitor; `~/.Xauthority` is pre-created; the X11-mode terminal runs under `dbus-run-session` so `xfconfd` works; and known-harmless noVNC/GTK/dbus messages are filtered out of the container log.
* [Changing] `PyOPUS` is ported from PyQt5 to PySide6. Its threaded plotting works unchanged; the `pyog` project GUI is removed, as its table models rely on PyQt5-specific virtual dispatch.
* [Changing] the Liberty files in `libs.ref` of all packaged PDKs are now also shipped gzipped as `.lib.gz`, which the PDKs' `librelane`/`openlane`/`qflow` configurations reference and every Liberty-reading tool in the image handles. **Deprecation notice:** the uncompressed `.lib` files are kept alongside for the next few releases and will then be removed, so please migrate your own flows to the `.lib.gz` paths. The SPICE model libraries in `libs.tech/`, which share the extension, are unaffected.
* [Fix] `librelane` could not read those gzipped Liberty files in `Toolbox.get_lib_voltage()`, so `OpenROAD.IRDropReport`, the **last** step of the `Classic` flow, aborted with `Syntax error in liberty file on line 1` after everything before it had passed. Designs setting `LIB`/`CELL_LIBS` themselves were unaffected. The image patches that function to decompress first; `gzopen()` alone does not do it, as `libparse.LibertyParser` reads through the stream's `fileno()`. Reported as [librelane issue #627](https://github.com/librelane/librelane/issues/627).
* [Fix] the PDK operating-point annotation symbols (`annotate_fet_params.sym`, `annotate_bip_params.sym`) showed `NaN` in every field in `2026.07`. An upstream reentrancy guard in `translate()` was held across the Tcl evaluation, so a `tcleval(...)` callback that itself calls `xschem translate` got an empty string back; `xschem` is bumped past `f583f470` ([issue #342](https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/342), [xschem issue #460](https://codeberg.org/stef_xschem/xschem/issues/460)).
* [Fix] `xschem` no longer asks whether embedded Tcl scripts may be executed, which the PDK launcher symbols and `tcleval()` attributes need. `xschem_execute_scripts yes` moved to the system-wide `xschemrc`: the user file was not enough, since `xschem` reads it only when the working directory has no `xschemrc` of its own, and every IIC design template ships one, so the setting was skipped in exactly the sessions that need it.
* [Fix] `start_vnc.sh` detects rootless Podman on macOS and Windows too. The check was gated on Linux, but the Podman machine VM is rootless as well and refuses host ports below 1024, so `WEBSERVER_PORT` stayed at `80` and container creation failed; `8080` is now auto-selected there as well. A failed start also reports the error and exits non-zero instead of still printing the VNC URL.
* [Fix] the start scripts prefixed `DOCKER_REGISTRY` to the image name even when `DOCKER_USER` already named a registry, which made a private registry unusable since `2026.07` (`docker.io/myregistry:5000/…` is an invalid reference). The prefix is now skipped when `DOCKER_USER` contains a `.` or a `:`, or is `localhost`, so `DOCKER_USER="myregistry:5000"` is all that is needed. `DOCKER_REGISTRY=none` forces unqualified names and is now available in the `.bat` scripts too, and an empty `DOCKER_USER` means the root of the registry.
* [Fix] a mouse button could get stuck down in the browser (noVNC) session, most easily the right one, after which X's implicit pointer grab sent every later click to the wrong window and focus and raising stopped working. Up to noVNC `1.5.0` the button mask is incremental state that is never re-synchronised, so a `mouseup` lost outside the window or to a native context menu leaves the bit set for good. Fixed upstream in `1.6.0`; native VNC viewers were never affected.
* [Fix] forcing VNC mode with `-V`/`--vnc`, as the entrypoint's own `--help` documents, killed the container a moment after the session came up: that flag skips the UI auto-detection, the only place that set `DISPLAY`, so `setxkbmap` failed with "Cannot open display" and `set -e` brought everything down. `DISPLAY` now defaults to `:1` whenever the VNC session starts without one.
* [Fix] the browser no longer serves a stale noVNC client after an image upgrade. `websockify` sends `Last-Modified` but no `Cache-Control`, so browsers fall back to heuristic freshness, which the `novnc` package's 2021 mtimes stretched to months. Every response now carries `Cache-Control: no-cache`. **Note:** a browser that already cached the old client cannot learn this from the server, so please reload the page once bypassing the cache (`Ctrl+Shift+R`, `Cmd+Shift+R` on macOS) after upgrading.
* [Fix] the `[INFO] noVNC HTML client started` line omitted the web server port, which misleads whenever `WEBSERVER_PORT` is not `80`, which is the default under rootless Podman. The `README` instructions had the same omission.
* [Fix] `XDG_RUNTIME_DIR` is created per user as `/tmp/runtime-<uid>` with mode `0700`, instead of the root-owned, world-writable `/tmp/runtime-default` shared by every UID, which violated the specification and made `dbus-daemon` disable its transient service directory. An externally provided `XDG_RUNTIME_DIR` (WSLg's, for example) is respected, `CONTAINER_XDG_RUNTIME_DIR` still overrides, and a forwarded Wayland socket is mounted at the neutral path `/tmp/host-wayland`.
* [Fix] `PySide6` was left broken by the removal of `PySide6-Addons`: both wheels ship the shared top-level files and `pip` does no cross-package reference counting, so uninstalling Addons deleted the `__init__.py` Essentials still needs, leaving `PySide6` a namespace package without `__version__` and breaking matplotlib's Qt backend and every GUI on top of it. Essentials is now force-reinstalled at the already resolved version.
* [Fix] `charlib` and `cir2py` are installed as wrappers that unset `PYTHONPATH` before launching their venv entry points, so the container-wide Python path no longer shadows CharLib's pinned `PySpice` fork; virtualenv binaries are no longer symlinked into `$TOOLS/bin`.
* [Fix] the `feed` parameter of the IHP `SG13CMOS5L` `cap_cmomi` capacitor can be set again in VACASK. The ngspice model writes the default symbolically and the conversion carried that over; VACASK treats such a parameter as derived and rejects every override with `Parameter 'feed' not found.`, which locked the device to `feed=double` and broke the `xschem` → VACASK path outright. Fixed in upstream's converter, and new test 29 covers `cap_cmomi` in both simulators against the capacitance the KLayout PCell prints in its own `C=` label.
* [Fix] the IHP `SG13CMOS5L` capacitor corners work in VACASK again. The PDKs install from a branch and gained `cap_cmomf` on 2026-08-11, which `cornerCAP.lib` includes in every section. VACASK's converter, however, names the models it handles in hardcoded lists, so the new device was skipped while the corner file including it was converted verbatim, and every deck pulling in that corner died on the missing include. The device lists are now completed from the installed PDK tree, so the next new device is covered too. Two install-time checks back it up: every include in the converted models must resolve, and every OSDI object the PDK's `.spiceinit` loads must exist.
* [Fix] the pcell inventory baselines of test 27 are updated for that PDK bump: `ihp-sg13g2` 37 → 38 pcells (`cap_cmomf`), `ihp-sg13cmos5l` 24 → 26 (`cap_cmomf`, `guard_ring`). No pcell is pinned as expected-empty, so the test names any new device that produces no geometry.
* [Fix] selecting the PDK at container start (`-e PDK=<pdk>`) now also selects the matching standard cell library. `STD_CELL_LIBRARY` was hardcoded to `sg13g2_stdcell`, so every other PDK silently kept pointing at the IHP `SG13G2` cells, and `GF_PDK_OPTION` was left unset for `gf180mcu`, where KLayout warns and assumes `D`. Both derive from `$PDK` now; an explicitly provided value still wins.
* [Fix] the KLayout PCell libraries of both IHP PDKs no longer break when two KLayout processes run at the same time. They preprocess each PCell module into `$TMPDIR/<module>_pre.py` under the bare module name, and both PDKs ship the same names, so on a shared `/tmp` the loser died with `FileNotFoundError`. That exception escapes the library constructor, so the PDK then registered *no* PCell at all: two KLayout windows, or a DRC job beside an interactive session, were enough. The file now carries the process ID, and test 27 gives each PDK run its own `TMPDIR`.
* [Fix] the `gf180mcuD` `efuse` PCell produces geometry instead of an empty cell. Two upstream bugs: `draw_efuse()` was called without its required `device_name` argument, and it read `efuse.gds` from a path nothing ever installs it to. Both cell libraries are patched at PDK-install time.
* [Fix] instantiating IHP PCells no longer floods the console: `sealring` shelled out to `git` in a tree carrying no `.git` and now reads the installer's `COMMIT` file, `isolbox`'s length and width defaults are corrected to the `3.6u` its own callback clamps to (geometry unchanged), and the ~35 `Box.destroy: already destroyed!` warnings per run are demoted to a verbosity-gated level.
* [Fix] `sak-pin-reorder.py` matches the `.subckt` card case-insensitively. Netlisters disagree on the spelling (`xschem` and Magic write `.subckt`, KLayout-PEX writes `.SUBCKT`), so every `kpex`-extracted netlist failed with "No .subckt line found in the netlist file". The source's spelling is carried through to the rewritten header.
* [Fix] the container works on SELinux hosts (Fedora, RHEL and clones). It runs as `container_t` while the bind-mounted GUI sockets and designs directory keep their host labels, so SELinux denied both: `start_x.sh` never showed a window and the container exited a few seconds after start, and `/foss/designs` was inaccessible in every mode. The start scripts now add `--security-opt label=disable` when the host kernel has SELinux enabled, which switches off type enforcement for that container only; relabelling the mounts instead is not an option, as the sockets belong to the host session. `IIC_OSIC_TOOLS_SELINUX_LABEL` selects another option or, exported empty, switches it off ([issue #352](https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/352), README section 5.1.1). Container options are fixed at create time, so an existing container has to be re-created.
* [Fix] a container that dies during startup no longer fails silently; the SELinux failure above produced no output at all. `start_x.sh`, `start_vnc.sh` and `start_jupyter.sh` now watch the container for a few seconds, print the tail of its log with a hint when it stops, and no longer advertise a VNC or Jupyter URL for a container that already exited (`IIC_OSIC_TOOLS_NO_STARTUP_CHECK` skips the wait). Inside, an unreachable X server is reported with the display, the authority file and the likely causes.
* [Fix] `install.sh` records the container engine you picked in `$HOME/.config/iic-osic-tools/env`, which the start scripts source. It was previously used for the installation only, so on a machine that also has a `docker` CLI (a leftover, or the `podman-docker` alias) the start scripts silently auto-detected Docker again. A value set in the environment still wins.
* [Build] the build-only compiler toolchains (`clang`/LLVM, `gnat`, `gfortran`) move to `base-dev` and the unused `ant` and `binutils-gold` are dropped; the runtime image keeps GCC, `mold` and only the matching shared libraries, saving about 300 MB.
* [Build] the Python Qt bindings are consolidated on `PySide6`, saving about 115 MB: `python3-pyqt5`/`-pyqt6` leave the runtime image (PyQt5 stays in `base-dev`, where the PyOPUS build needs it), the Qt libraries they dragged in are requested explicitly, and four unused Qt packages plus `PySide6`'s translations and QML modules are dropped. Both Qt runtimes stay: OpenROAD's GUI is Qt5-only, KLayout, Kactus2 and Qucs-S are Qt6.
* [Build] no `pip` download cache reaches the image anymore. `PIP_NO_CACHE_DIR` is exported, since `--no-cache-dir` covers only the outer `pip` and not the nested one PEP 517 build isolation runs, which left about 55 MB of residue. The leftover `rustup` directory is cleaned up at the end of the EDA install, since later build steps re-created it.
* [Build] every `FIXME` in the build scripts and the ORFS test is resolved: the obsolete `GDS_ALLOW_EMPTY` export is dropped, the `rftoolkit` pins are confirmed against upstream `HEAD`, the `gobject-introspection` patch documents the exact condition for dropping it and now fails loudly when upstream moves, the `sky130A` KLayout tech-file repairs are guarded so the build reports when `open_pdks` no longer needs them, and the OpenMPI note is marked a permanent container constraint rather than a defect.
* [Build] the Python regression tests are extended: `PySide6` is checked for a valid `__version__`, importable `chipify`/`snp2le` Qt entry points and complete on-disk files against the installed wheel `RECORD`; the CharLib test verifies the `PySpice` API actually used and that `charlib` on `PATH` is the wrapper script.
* [Docs] normalized the project name to `IIC-OSIC-TOOLS` throughout the documentation and the install scripts.
* [Docs] the "Overwriting Shell Variables" examples in `README.md` set `DOCKER_USERNAME`, which no script reads, so following them changed nothing; they set `DOCKER_USER` now.

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
