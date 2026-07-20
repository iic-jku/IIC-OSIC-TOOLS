# Build Script vs Upstream — Comparison Findings

**Scope:** all 50 tool build recipes under `_build/images/*/scripts/install.sh` (plus
Dockerfile `ARG` pins and the `open_pdks` inline installers).
**Axis:** build-recipe fidelity — do the local build steps (configure flags, deps,
patches, install targets) match each tool's *upstream canonical* build?
**Date:** 2026-07-06 · branch `next_release`

## Methodology & caveat

Each `install.sh` was read in full and compared to the pinned upstream project's
documented build procedure. High-deviation recipes (magic, OpenROAD, yosys, verible,
Xyce, ngspice) were cross-checked against upstream docs over the web. Standard
autotools (`./configure && make && make install`) and standard CMake
(`cmake .. && make && make install`) recipes were assessed against the canonical
pattern for that build system rather than an individual doc fetch. Verdicts:

- ✅ **Match** — follows the upstream canonical build.
- ⚠️ **Deviation (justified)** — differs from vanilla upstream, but the change is an
  in-script, commented workaround (Ubuntu 24.04 toolchain, arch portability, RPATH,
  size stripping, PDK integration). Behaviour-preserving; not a defect.
- 🚩 **Discrepancy** — genuine inconsistency worth a maintainer's attention.

---

## Headline findings

| # | Severity | Tool | Finding |
|---|----------|------|---------|
| 1 | ✅ RESOLVED | verible / pulp-tools | **Was:** two Verible versions in one toolset — standalone `verible` image built `v0.0-4080-ga0a8d8eb` from source while `pulp-tools` shipped prebuilt `v0.0-3724-gdec56671`. The older pulp copy shadowed the newer one on PATH (first-wins symlink dedup in `install_links.sh`, `pulp` < `verible` alphabetically). **Fix:** removed the Verible download block + `VERIBLE_VERSION` ARG from `pulp-tools`; Verible now served solely by the dedicated `verible` image. Single source of truth, no collision. |
| 2 | ✅ note | yosys | Pinned `v0.66` builds via the Makefile (`make CONFIG=gcc ENABLE_PYOSYS=1`). **This is the upstream-canonical build for v0.66** — the latest release tag. CMake (`cmake -B build`) exists only on unreleased `main` (no `CMakeLists.txt` at v0.66, confirmed HTTP 404). Recipe is correct; rewrite to CMake only when a post-0.66 release ships the migration. |
| 3 | ⚠️ | openroad / openroad-librelane | Upstream builds deps via `DependencyInstaller.sh`; here SWIG 4.3.0 and spdlog 1.15.1 are compiled from source and `/usr/include/tcl/tcl.h` is patched to inject `Tcl_Size`. Functionally aligned with upstream's dep requirements but a hand-rolled substitute. |

No incorrect URL/commit pins, no copy-paste tool mixups, and no missing build steps
were found. (The `VACASK_*` ARGs in `open_pdks/Dockerfile` are **used** — by
`install_ihp.sh` for IHP-PDK VACASK prep — not dead code.)

---

## Justified deviations (⚠️) — commented workarounds, not defects

| Tool | Deviation from vanilla upstream | Reason (per script comment) |
|------|--------------------------------|------------------------------|
| magic | extra `make database/database.h` before `make -j` | serialize a parallel-build header race |
| ngspice | double build (libngspice `--with-ngshared`, then executable), `make distclean` between; adds OSDI/BSIMCMG models | `-fvisibility=hidden` would hide `Cosim_setup` in ivlng.so (issue #287); model files for IHP/ASAP7 |
| openroad(+librelane) | build SWIG 4.3 + spdlog 1.15.1 from source; patch `tcl.h`; `-DUSE_SYSTEM_BOOST=ON -DBUILD_GUI=ON` | Ubuntu 24.04 ships SWIG 4.2 / spdlog 1.8.1 / Tcl 8.6 |
| yosys | `sed` to add `-Wno-error=unused-parameter` to Makefile | pyosys build failure workaround |
| klayout | `build.sh -qmake qmake6` **with** Qt bindings (not `-without-qtbinding`) | Qt bindings needed for DRC/LVS (issue #111) |
| gtkwave | `patchelf --set-rpath` on libgtkwave.so / rtlbrowse | meson build omits install_rpath for libfst |
| gds3d | `sed` add `-std=c++11` to linux/Makefile | GCC-11 fix (upstream PR #9) |
| rftoolkit | multiple `sed` on FastHenry/FasterCap Makefiles + CMake (`-fcommon`, drop `-m64`, cmake version bump); pin helper libs LinAlgebra/Geometry | aarch64 portability + 24.04 build fixes |
| libman | `sed` Qt SkipEmptyParts; `CONFIG+=no_core`; copy capnp libs + `patchelf` RPATH | Qt6 API, private CORE repo unavailable, capnp built from source |
| xyce-xdm | `sed isnan → std::isnan` (3 files) | compile fix on newer libstdc++ |
| slang | build header-only Boost 1.88 in /tmp, point CMake at it | Ubuntu Boost 1.83 lacks `concurrent_flat_set.hpp` |
| vacask | static Boost 1.88; `-march=x86-64-v2` on x86_64 | stock Boost too old; avoid AVX-512 on consumer CPUs |
| covered | plain `make` (no `-j`) | parallel build randomly fails |
| kactus2 | `sed` LOCAL_INSTALL_DIR in .qmake.conf | redirect install prefix |
| verilator / riscv-gnu-toolchain / spike | `strip` binaries; size-opt `-Os -g0` / `-Wl,-s` | image-size reduction |
| ghdl | `--with-llvm-config` (LLVM<15) | LLVM backend build |
| open_pdks | install via `ciel enable <open_pdks-commit>`, prune sky130B, patch klayout `.lyt`, gdsfactory `A-B`→`-` | PDK packaging, not a compile |

---

## Matches upstream canonical build (✅)

Standard autotools / CMake / cargo / release-download recipes, no material deviation:

`xschem`, `netgen`, `irsim`, `cvc_rv`, `gaw3-xschem`, `qflow`, `iverilog`,
`nvc`, `qucs-s`, `kepler-formal`, `palace`, `spike` (pk build), `surelog`,
`slang-yosys-plugin`, `ghdl-yosys-plugin`, `verible` (bazel `:install-binaries`
+ `simple-install.sh` — exact upstream steps), `surfer` (cargo), `openvaf` (cargo),
`veryl` (verylup), `pulp-tools/bender` (cargo), `pulp-tools/sv2v` (stack),
`padring` (bootstrap+ninja), `fpga-tools` (icestorm+nextpnr, standard),
`ngspyce`/`pyopus` (pip), `osic-multitool` (git checkout), `svck` (wrapper),
`spicebind` (cmake), `uv` (release binary), `xyce`+`trilinos-12.12.1`
(**confirmed correct** — Xyce building guide mandates Trilinos 12.12.1),
`open_pdks/ciel`, `openems` (cmake + pip bindings), `gds3d` core, `kactus2` core.

---

## Recommended actions

1. ~~**Reconcile Verible** (finding #1)~~ — **DONE.** Verible dropped from `pulp-tools`;
   the dedicated `verible` image is the single source. No version collision on PATH.
2. **Track yosys build-system migration** (finding #2): the `make CONFIG=gcc` recipe
   is a landmine for the next version bump past the CMake cutover.
3. Everything else: deviations are legitimate and well-commented; keep the comments
   attached so future bumps know why each hack exists.
