# Upgrade the base image from Ubuntu 24.04 LTS to 26.04 LTS

> Status: **planned, not started.** Written 2026-09-08 against `next_release`.
> Package availability was verified against the `resolute` archive on that date;
> re-run the Phase 0 pre-flight before acting on any of it.
>
> Refreshed 2026-11-09 against `next_release` at `44d1084a` (158 commits after the first
> draft). Work happens on branch `ubuntu-26.04-upgrade`, cut from that commit. File:line
> anchors below are as of that commit, so re-grep after a rebase. Changes since the draft:
> slang's Boost source build is already gone (`51093a23`), OpenROAD builds with Bazel
> (`4cba3f69`), `libopenmpi-dev` and a block of xcb/xkbcommon/dbus/fontconfig runtime
> libraries joined the base image, `libman` became `door`, `opencdc` and `prep-ic` were
> added, PyOPUS is PySide6-native, and the vtk wheel is stripped. The apt and PyPI package
> lists grew, so the 2026-09-08 resolute verification does **not** cover them: Phase 0
> must be re-run.

## Context

The image has been on Ubuntu 24.04 LTS ("noble") since release `2025.01` (`RELEASE_NOTES.md:292`).
Ubuntu 26.04 LTS ("resolute", Resolute Raccoon) was released 2026-04-23 and has had its `.1`
point release, so the archive is settled.

24.04 is supported until 2029, so this is not urgent — the payoff is toolchain freshness and
debt removal. Four workarounds in this repo still exist only because 24.04 was too old (a
fifth, slang's Boost 1.88 build, was already dropped on `next_release` by `51093a23`, because
the pinned slang no longer needs it), and the distro now ships adequate versions of all of them:

| Workaround | Reason it exists | Status on 26.04 |
|---|---|---|
| `71_fix_gobject_introspection.sh` | g-i 1.80 imports `distutils.msvccompiler` | g-i 1.86 — **must** be deleted, script hard-fails by design |
| Boost 1.88 source build (vacask only) | noble's 1.83 lacks `concurrent_flat_set.hpp` | default Boost is 1.90 |
| spdlog 1.15.1 source build (openroad-librelane) | noble ships 1.12 | archive ships 1.15 |
| `OMPI_MCA_btl_vader_*` | OpenMPI 4.1.6 | OpenMPI 5.0.10, knob renamed `..._btl_sm_...` (the runtime base now also carries `libopenmpi-dev`, see Phase A) |
| `30_install_boost.sh`, `34_install_spdlog.sh` | — | already 100 % commented out, dead files |

**Intended outcome:** a 26.04-based image, both arches green on the full `_tests` suite, with
those workarounds gone, shipped as a distro-only release.

**What 26.04 brings:** Python 3.12 → **3.14**, GCC 13 → **15**, CMake 3.28 → **4.2**, SWIG →
4.4, OpenMPI 4 → **5.0.10**, Boost 1.83 → **1.90**, Qt6 6.4 → 6.10.2, Node 22, glibc 2.43.
Verified non-blockers: **Qt5 is still in the archive** (5.15.18, universe — LibreLane OpenROAD's Qt5-only
GUI and Qt5-built VTK are safe), **llvm-18/clang-18 still packaged** (1:18.1.8), **openjdk-17
still packaged**, and the **mozillateam PPA publishes for `resolute`** (firefox 155).

**Decisions taken:** stay on LLVM 18 this cycle (LLVM 21 is a separate follow-up); remove the
obsolete workarounds, one commit each; bump PyPI pins where Python 3.14 forces it; gate the
release on **both** amd64 and arm64.

**Target release:** `2027.01`, mirroring the 22.04 → 24.04 cadence (24.04 shipped April 2024,
adopted in `2025.01`). The tag is `date +%Y.%m` in `build-all.sh`, so it is set by the month
the final build runs.

---

## Ground truth about the build

- The distro is pinned in exactly **one** place: `_build/images/base/Dockerfile:7`
  (`ARG BASE_IMAGE=ubuntu:noble`). Nothing overrides it.
- Graph: `base` (runtime) → `base-dev` (toolchain) → ~50 tool images → `image-full`
  (`_build/images/iic-osic-tools/Dockerfile`), which is `FROM base` and `COPY --link`s each
  tool's `${TOOLS}` tree in. The `tools` group has 50 targets today (the count drifts, read
  it from `docker-bake.hcl`). **Tools are compiled in `base-dev` and run in `base`**, so a
  runtime library pin that disagrees with what `base-dev` linked against produces a broken
  image that builds cleanly. This is the central hazard of the upgrade.
- `base` already compiles or-tools 9.14 as a CMake superbuild
  (`_build/images/base/scripts/31_install_or-tools.sh`), so GCC 15 / CMake 4 bite in Phase B,
  not only in the tools.
- OpenROAD (the `openroad` target) is built with **Bazel** through `bazelisk`, installed in
  `base-dev/scripts/install.sh`. Bazel fetches its own toolchain and Qt, so CMake 4 and GCC 15
  matter less there. It does link the system xcb/xkbcommon libraries on arm64, which is why
  `base-dev` gained the `libxcb-*-dev` set. `openroad-librelane` is still a CMake build.
- The runtime `base` now keeps `libopenmpi-dev` (and with it gfortran): Xyce's installed
  headers include `<mpi.h>` and `buildxyceplugin` compiles with `mpicxx`. On resolute that
  package is OpenMPI 5, so the plugin build path needs a test, not just the package rename.
- `install_eda.sh` runs in `image-full` — the **last and most expensive** step. The entire
  Python 3.14 blast radius surfaces there unless it is pre-flighted.
- `_build/build-target.sh` passes its argument unquoted to bake, so
  `./build-target.sh "yosys magic xschem"` builds a batch.
- `docker-bake.hcl` exposes `IMAGE`, `REGISTRY`, `PLATFORMS`, `DEPS_FROM_TARGETS`,
  `CACHE_EXPORT` as bake variables settable from the environment. `IMAGE` is the rollback lever.
- `DOCKER_LOAD=1` (`--load`) is single-platform only — pair it with `PLATFORMS=linux/amd64`.
- `builder-create.sh` makes docker contexts `tools-builder-$USER-linux-{amd64,arm64}` on
  `ssh://$USER@buildx86` / `@buildaarch`. Those give **native** throwaway containers per arch
  for pre-flight — no qemu.

---

## Phase 0 — Pre-flight (minutes of cost, hours of value)

Do this **before touching any file**. Both checks run in throwaway `ubuntu:resolute`
containers on the real builder hosts.

### 0.1 Validate every apt list against resolute, both arches

Extract the package names from the four `apt-get install` sites and check each against the
resolute archive, then solve the whole set at once (a per-package check cannot catch conflicts):

```bash
for ARCH in amd64 arm64; do
  echo "###### $ARCH"
  docker --context tools-builder-$USER-linux-$ARCH run --rm \
    -v /Users/harald/iic-osic-tools:/src:ro ubuntu:resolute bash -euo pipefail -c '
      export DEBIAN_FRONTEND=noninteractive
      apt-get -qq update >/dev/null
      for f in /src/_build/images/base/scripts/00_base_install.sh \
               /src/_build/images/base-dev/scripts/install.sh \
               /src/_build/images/base/scripts/80_install_apps.sh \
               /src/_build/images/iic-osic-tools/skel/headless/scripts/install_eda.sh; do
        echo "=== $f"
        pkgs=$(awk "/apt-get[^#]*install/{c=1} c{print} c&&!/\\\\\$/{c=0}" "$f" \
               | sed -e "s/.*install//" -e "s/\\\\//g" | tr " \t" "\n\n" \
               | grep -Ev "^$|^-|^\*|^y$" | sort -u)
        for p in $pkgs; do apt-cache show "$p" >/dev/null 2>&1 || echo "  MISSING: $p"; done
        apt-get -s install --no-install-recommends $pkgs >/dev/null || echo "  SET NOT SOLVABLE"
      done'
done
```

Known-good noise: `firefox` and `sbt` come from the mozillateam PPA and the scala repo, neither
configured in the throwaway container. Everything else printing `MISSING:` is a real rename.

Packages added since the 2026-09-08 verification, never checked against resolute, so watch
these first: `libdbus-1-3`, `libfontconfig1`, `libice6`, `liblz4-dev`, `libopenmpi-dev`,
`universal-ctags`, the `libxcb-*` runtime set (`icccm4`, `image0`, `keysyms1`, `randr0`,
`render-util0`, `render0`, `shm0`, `shape0`, `sync1`, `util1`, `xfixes0`, `xinerama0`, `xkb1`),
`libxkbcommon0`, `libxkbcommon-x11-0` and their `-dev` twins in `base-dev`. Candidates for
a `t64` or SONAME rename. `bazelisk` is a release download, not apt, so 0.1 does not see it.

Settle the Boost question empirically in the same container — Boost.System went header-only, so
confirm which of the eight runtime packages exist at 1.90:

```bash
docker --context tools-builder-$USER-linux-amd64 run --rm ubuntu:resolute bash -c '
  apt-get -qq update >/dev/null; apt-cache policy libboost-dev | head -3
  for c in filesystem iostreams program-options python serialization system test thread; do
    printf "%-16s runtime:%s dev:%s\n" "$c" \
      "$(apt-cache show libboost-$c1.90.0 >/dev/null 2>&1 && echo yes || echo NO)" \
      "$(apt-cache show libboost-$c-dev   >/dev/null 2>&1 && echo yes || echo NO)"
  done'
```

### 0.2 Validate the pinned PyPI packages against Python 3.14, both arches

Mirror the real environment: apt-provided `python3-gmsh`/`python3-cvxopt` visible through
`--system-site-packages`, exactly as `install_eda.sh:8-14` requires (upstream gmsh ships no
aarch64 wheel).

```bash
for ARCH in amd64 arm64; do
  echo "###### $ARCH"
  docker --context tools-builder-$USER-linux-$ARCH run --rm \
    -v /Users/harald/iic-osic-tools:/src:ro ubuntu:resolute bash -euo pipefail -c '
      export DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1
      apt-get -qq update >/dev/null
      apt-get -qq install -y python3 python3-pip python3-venv python3-dev \
                             python3-gmsh python3-cvxopt python3-tk >/dev/null
      python3 -m venv --system-site-packages /tmp/v; . /tmp/v/bin/activate
      pip -q install -U pip; python3 -V
      specs=$(sed -n "56,89p" /src/_build/images/iic-osic-tools/skel/headless/scripts/install_eda.sh \
              | sed -e "s/\\\\$//" -e "s/\"//g" | tr -d " \t" | grep -E "^[A-Za-z]")
      for s in $specs; do
        if   pip download --no-deps --only-binary=:all: -d /tmp/w "$s" >/tmp/l 2>&1; then echo "WHEEL   $s"
        elif pip download --no-deps                     -d /tmp/w "$s" >/tmp/l 2>&1; then echo "SDIST   $s   <-- source build"
        else echo "FAIL    $s :: $(tail -3 /tmp/l | tr "\n" " ")"; fi
      done
      echo "--- full resolve ---"; pip install --dry-run $specs 2>&1 | tail -25'
done
```

Repeat for the unpinned base list (`70_install_from_pip.sh:11-54` and `:57-61`). `pipdeptree`
is no longer pinned `<4` there, so it is a new aarch64 check: the pin was added because 4.x
had no aarch64 wheel and needed a Rust build. `install_eda.sh` still installs `vtk`/`pyvista` as
`setupEM` dependencies before removing them (:172), so a cp314 `vtk` wheel must exist on both
arches or the pip step fails before the removal runs. `SDIST` on arm64 for a
C-extension package (`gdspy`, `cocotb`, `siliconcompiler`, `scikit-rf`) is the pain signal;
`FAIL` means a forced pin bump. **`gdspy==1.6.13` is the known risk** — upstream is
maintenance-only, tested to Python 3.8, and directs users to `gdstk`; 1.6.13 is the last
release, so if it will not build there is no newer pin to move to.

**Deliverable:** a table of (a) apt renames still unknown, (b) PyPI pins needing a bump, per
arch. Do not start a build until both are empty or decided.

---

## Phase A — The flip and the apt renames (one commit)

| File | Edit |
|---|---|
| `_build/images/base/Dockerfile:7` | `ARG BASE_IMAGE=ubuntu:resolute` |
| `_build/images/base/Dockerfile:36-41` | `ENV OMPI_MCA_btl_sm_single_copy_mechanism=none`; rewrite the comment (the `vader` note at :39-40 becomes historical) |
| `_build/images/base/Dockerfile:56` | delete the `71_fix_gobject_introspection.sh` line; `git rm` the script |
| `_build/images/base/scripts/00_base_install.sh` | the renames below |
| `_build/images/base-dev/scripts/install.sh` | delete `libboost-system-dev` (:43) and `libpcre3-dev` (:85) — both gone from resolute; `libpcre2-dev` at :84 already covers the latter |

Renames in `00_base_install.sh` (the names were verified against the resolute archive on
2026-09-08, line numbers are as of `44d1084a`):

- `libcapnp-1.0.1` → `libcapnp-1.1.0` (:112)
- `libgit2-1.7` → `libgit2-1.9` (:130)
- `libhdf5-103-1` → `libhdf5-310` (:139)
- `libopenmpi3` → `libopenmpi40` (:159). `libopenmpi-dev` (:158) needs no rename but pulls
  OpenMPI 5 headers, see the Xyce plugin note under "Ground truth".
- **delete** `libpcre3` (:161) — removed from the archive; `libpcre2-8-0` (:160) stays
- `libre2-10` → `libre2-11` (:177)
- `libspdlog1.12` → `libspdlog1.15` (:180)
- `libtomlplusplus3` → `libtomlplusplus3t64` (:186)
- `libvtk9.1t64` → `libvtk9.5`, `libvtk9.1t64-qt` → `libvtk9.5-qt` (:188-189)
- `libwxgtk3.2-1` → `libwxgtk3.2-1t64` (:190)
- `libzip4` → `libzip5` (:220)
- **strip** `t64` from `libqt6openglwidgets6t64` (:171), `libqt6printsupport6t64` (:172),
  `libqt6xml6t64` (:176) — but **keep** it on `libqt6core6t64` (:168), `libasound2t64` (:99),
  `libqt5sql5t64` (:164), `libqt5xml5t64` (:166). The Qt6 t64 transition is partially reverted;
  the others are not.
- Boost runtime pins `libboost-*1.83.0` → `1.90.0` (:101-108), dropping any component that 0.1
  showed has no 1.90 runtime package (expect `libboost-system1.90.0` to be gone). **This must
  match `base-dev`'s unversioned `libboost-*-dev`, which now resolves to 1.90** — leaving the
  runtime at 1.83 gives a SONAME mismatch that builds cleanly and fails at runtime.

**Not changed:** `libgnat-13`, `libllvm18`, `libomp5-18`, `libtcl8.6`, `libncurses6`,
`libqhull-r8.0`, `libjpeg-turbo8`, `libjudydebian1`, `libmng2`, `usbutils-py`, `rustup`,
`libgirepository-1.0-1`, all Qt5 packages, all `clang-18`/`llvm-18` dev packages, `libgcc-13-dev`
— all still present in resolute (as of 2026-09-08). The mozillateam PPA line
(`80_install_apps.sh:9,23`) derives the codename from `/etc/os-release`, so it needs no edit.

Re-run 0.1 after this commit; require clean output.

---

## Phase B — Build and iterate `base` + `base-dev`, amd64 only

Isolate the whole experiment in its own registry namespace so no noble tag is ever overwritten:

```bash
cd /Users/harald/iic-osic-tools/_build
export IMAGE=iic-osic-tools-resolute PLATFORMS=linux/amd64
DRY_RUN=1 ./build-base.sh    # check the invocation first
./build-base.sh && ./build-base-dev.sh
```

Iteration loop (or-tools is the likely first casualty of CMake 4 / GCC 15):

```bash
PLATFORMS=linux/amd64 DOCKER_LOAD=1 ./build-base.sh
docker run --rm -it --entrypoint /bin/bash registry.iic.jku.at:5000/iic-osic-tools-resolute:base
NO_CACHE=1 ./build-target.sh base    # only when a cached layer is suspect
```

Gate before leaving Phase B:

```bash
docker run --rm --entrypoint /bin/bash registry.iic.jku.at:5000/iic-osic-tools-resolute:base -lc '
  python3 -V; gcc --version|head -1; cmake --version|head -1; swig -version|grep SWIG
  dpkg -l | grep -E "libboost.*1\.[0-9]+\.0|libspdlog|libvtk9"
  python3 -c "import gi" && echo "g-i OK (71_* correctly deleted)"'
```

Then run the pip block of `install_eda.sh` against the real resolute `base` — this pulls the
`image-full` failure mode forward by roughly ten hours:

```bash
docker run --rm -v /Users/harald/iic-osic-tools:/src:ro \
  --entrypoint /bin/bash registry.iic.jku.at:5000/iic-osic-tools-resolute:base -lc '
    sed -n "50,89p" /src/_build/images/iic-osic-tools/skel/headless/scripts/install_eda.sh \
      | sed "s/\$PIP_FLAGS/--upgrade --no-cache-dir --break-system-packages/" > /tmp/pip.sh
    bash -e /tmp/pip.sh'
```

(The rest of `install_eda.sh` needs `$PDK_ROOT` and `$TOOLS/veryl`, so it cannot run standalone.
That includes the PySide6 trim at :145-151 and the vtk/pyvista removal at :172. Both are
version-sensitive, so check the PySide6 6.12 wheel layout on 3.14 once `image-full` runs.)

---

## Phase C — Retire the obsolete workarounds (one commit each)

One commit per item, so any single one can be restored individually if resolute turns out to
still need it.

| File / lines | Action |
|---|---|
| `_build/images/openroad-librelane/scripts/install.sh:8-17` | drop the spdlog 1.15.1 source build (system `libspdlog-dev` is 1.15). **Keep** the `Tcl_Size` shim at `:31-40` — grep-guarded and keyed to the pinned OpenROAD revision, not the distro. Its comment mentions SWIG 4.2, update it for 4.4 |
| ~~`_build/images/slang/scripts/install.sh`~~ | **already done** on `next_release` by `51093a23` (2026-10-14), slang builds against the system Boost 1.83 with the pinned revision. Nothing to do here, but re-check that slang (and `opencdc`, which builds on it) still configures against Boost 1.90 |
| `_build/images/vacask/scripts/install.sh:18-43`, `:70` | drop the Boost source build and `-DBoost_ROOT`. **Keep** `BOOST_PROCESS_V2_DISABLE_PIDFD_OPEN` — a container/pidfd constraint, not a Boost-version workaround; re-verify the macro name against Boost 1.90 Process v2 |
| `_build/images/base/scripts/30_install_boost.sh`, `34_install_spdlog.sh` + `base/Dockerfile:49,53` | both files are entirely commented out — delete the files and their Dockerfile lines |
| `_build/images/base/scripts/31_install_or-tools.sh:25-29` | the comment says "system Boost 1.88" while the pins said 1.83 — correct to 1.90; keep the `rm` of the bundled Boost |
| `_build/images/base/scripts/80_install_apps.sh:98-99` | cosmetic — the "noble ships noVNC 1.3.0" rationale now refers to resolute |

Rebuild `base`/`base-dev` after the or-tools and dead-file commits; the rest lands in Phase D.

---

## Phase D — The ~50 tools, risk-batched (amd64 first)

With `base`/`base-dev` pushed under the trial namespace, set `DEPS_FROM_TARGETS=0` so each tool
resolves its parent **from the registry** instead of re-solving the whole DAG. That makes
per-target failures cheap and attributable; the cost is that the `tools-level-1..4` ordering in
`docker-bake.hcl` must then be respected manually (the groups exist for exactly this).

**D0 — canaries, serial.** Highest risk × longest runtime, so they also set the wall clock:

```bash
export IMAGE=iic-osic-tools-resolute PLATFORMS=linux/amd64 DEPS_FROM_TARGETS=0
for t in openroad openroad-librelane klayout xyce palace openems slang pyopus; do
  ./build-target.sh "$t" 2>&1 | tee /tmp/build-$t.log || echo "FAILED: $t" >> /tmp/failures
done
```

Why these: `openroad-librelane` combines CMake 4 + Boost 1.90 + SWIG 4.4 + Tcl + or-tools,
`openroad` is a Bazel build through `bazelisk` (hermetic toolchain and Qt, so CMake 4 and GCC 15
are mostly moot, but the bazelisk/Bazel download and the system xcb/xkbcommon link on arm64 are
new failure surface); `klayout` builds Python C-API bindings against 3.14 via `qmake6` (the pin
is 0.30.13 with the 0.30.12 Qt6 bindings, `44d1084a`); `xyce` is autotools
+ gfortran/Trilinos + OpenMPI 5; `palace` is a CMake superbuild (MFEM/PETSc/SLEPc), the most
likely `cmake_minimum_required(VERSION <3.5)` casualty; `openems` is CMake + Cython + VTK 9.5 +
Qt5; `slang`/`vacask` make the Boost decision concrete; `pyopus` is a Python sdist with C
extensions that hard-fails if `dist-packages` is not found (`pyopus/scripts/install.sh:28`).
PyOPUS now ports itself to PySide6 upstream, so the install deletes its duplicate PySide6
copy (`:30`) and the old local port is gone, but the sdist still needs `python3-pyqt5` in
`base-dev` on aarch64 (`base-dev/scripts/install.sh:136`).

**D1–D4 — the rest, level by level.** bake fails fast, so loop rather than building the whole
group:

```bash
for t in $(docker buildx bake -f docker-bake.hcl --print tools-level-1 | jq -r '.group["tools-level-1"].targets[]'); do
  grep -qx "$t" /tmp/done || { ./build-target.sh "$t" >/tmp/build-$t.log 2>&1 \
     && echo "$t" >> /tmp/done || echo "FAILED: $t" >> /tmp/failures; }
done
```

Repeat for `tools-level-2`, `-3`, `-4`. Level 2 now holds `opencdc` (built on `slang`), so it
needs the trial-namespace `slang` image in the registry first. Then re-enable the DAG for final assembly:

```bash
unset DEPS_FROM_TARGETS
DOCKER_TAGS=resolute-test PLATFORMS=linux/amd64 ./build-images.sh
```

**Expected failure classes, in the order they will appear, and the standard fix:**

1. **CMake 4** rejecting `cmake_minimum_required(VERSION <3.5)` → add
   `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` to *that tool's* cmake call, with a comment naming the
   upstream issue. Per-tool, not a global `ENV` — a global setting hides which tools are stale
   and makes the debt invisible at the next LTS.
2. **GCC 15** (`-std=gnu23` by default, stricter about missing `<cstdint>`/`<stdint.h>`) →
   prefer patching the upstream source; fall back to `CFLAGS=-std=gnu17` or
   `CC=gcc-14 CXX=g++-14` **for that tool only** (gcc-13/14 are still in the archive). A global
   pin would silently keep the image on a compiler that will disappear.
3. **Python 3.14 C-API** in `klayout`, `ngspyce`, `spicebind`, `pyopus`, `openems` → needs an
   upstream version bump in `_build/tool_metadata.yml`; surface these rather than patching.
4. **Rust tools** (`openvaf`, `surfer`, `veryl`, `uv`, `svck`, `pulp-tools`) are near-zero risk;
   the only exposure is resolute's `rustup` package and `openvaf`'s static LLVM 18 link, which
   is unaffected since LLVM 18 stays.

**arm64 only after amd64 is fully green.** Then `unset PLATFORMS` (back to the
`linux/amd64,linux/arm64` default) and rerun D0 → D4 → `build-images.sh`. Expect arm64-only
failures in exactly the two places Phase 0.2 already surfaced: PyPI sdists with no aarch64
wheel, and `pyopus` (which needs `python3-pyqt5` on aarch64 per `base-dev/scripts/install.sh:20-24`).
Budget one full cold build per arch — a single-arch cache does not help the other.

---

## Phase E — Documentation (last commit)

- `README.md:13` — "Ubuntu 24.04 LTS (since release `2025.01`)" → 26.04 LTS with the new tag.
- `.github/copilot-instructions.md:5` (base OS) and `:123` ("System Python 3.12" → 3.14).
- `KNOWN_ISSUES.md` — the xschem/Windows-11 note that the draft anchored at `:21` is gone
  (no Ubuntu 24.04 anchor is left in the file), so nothing to do. Re-grep for `24.04` and
  `noble` across the docs at this point. `README.md:500` mentions an Ubuntu 24.04 *host*
  timing, which is a measurement and stays.
- `RELEASE_NOTES.md` — new `## YYYY.MM` section at the top (the newest today is `## 2026.11`),
  following the precedent at `:292`:
  - `[Update] Upgrade base OS to Ubuntu 26.04 LTS (from 24.04 LTS)` — noting Python 3.14,
    GCC 15, CMake 4, OpenMPI 5, Boost 1.90
  - `[Remove]` lines for the gobject-introspection patch (its own header documents the
    hard-fail-as-signal contract, so the removal is worth calling out), and the spdlog
    and vacask Boost source builds (slang's already went out with `51093a23`)
  - `[Update]` line per forced PyPI pin bump

---

## Verification

**Capture the baseline first, on 24.04, before Phase A** — the joblog is the diff artifact:

```bash
cd /Users/harald/iic-osic-tools/_tests
IIC_TEST_RUNDIR=/mnt/scratch/osic-baseline ./run_integration_tests.sh hpretl/iic-osic-tools:latest
# keep /mnt/scratch/osic-baseline/<rand>/joblog.tsv
```

**Fast smoke set** after every `image-full` rebuild — covers Python, each language toolchain and
the desktop plumbing without the multi-hour flows: tests `03` (Python imports, PySide6
completeness, CharLib venv), `05`/`06` (ngspice), `09` (RISC-V), `12` (iverilog), `16` (VACASK),
`17` (Veryl), `27` (KLayout PCells), `30` (xdg-mime). Add the tests that exercise the
newer pieces: PyOPUS and the OpenMPI-5 Xyce plugin path (find them in `_tests/TESTS.md`),
since both changed after the draft.

**Two checks the existing tests do not cover**, aimed squarely at the base/base-dev split hazard:

```bash
IMG=registry.iic.jku.at:5000/iic-osic-tools-resolute:resolute-test
# 1. missing SONAMEs across every shipped binary -- catches a runtime pin (Boost, VTK,
#    spdlog, OpenMPI) that no longer matches what base-dev linked against
docker run --rm --entrypoint /bin/bash $IMG -lc '
  find /foss/tools -type f -perm -u+x -exec ldd {} \; 2>/dev/null | grep "not found" | sort -u'
# 2. Python dependency-graph consistency after the 3.14 move
docker run --rm --entrypoint /bin/bash $IMG -lc 'pip3 check; python3 -V'
```

Check 1 must print nothing. Check 2 must show only the known-harmless notes documented in
`install_eda.sh`: the PySide6 meta-package wanting the removed Addons/WebEngine/Pdf wheels
(:139-140) and `setupEM` missing `pyvista` and `pyvistaqt` (:169).

**Full run**, both arches, on the respective builder hosts, then diff against the baseline:

```bash
IIC_TEST_NO_PULL=1 IIC_TEST_RUNDIR=/mnt/scratch/osic-resolute \
  ./run_integration_tests.sh registry.iic.jku.at:5000/iic-osic-tools-resolute:resolute-test
```

A large runtime regression on a *passing* test (e.g. `28`) is as much a signal as a failure — it
usually means a tool fell back to a slower path (no OpenMP, MPI shared-memory transport disabled
by a wrong `OMPI_MCA_*` name, BLAS swapped to the reference implementation). Also compare
`docker image inspect --format '{{.Size}}'` old vs new: a large jump usually means a pip package
that was a wheel on 3.12 and is now a source build dragging headers in.

`_tests/27/check_pcells.py` pins exact PCell counts — if it fails, confirm whether the PDKs
legitimately changed (they track the IHP `dev` branch tip, see `KNOWN_ISSUES.md:166-178`) before
treating it as an upgrade regression.

---

## Rollback

- **Nothing published changes until the very last step.** With `IMAGE=iic-osic-tools-resolute`,
  the noble `registry.iic.jku.at:5000/iic-osic-tools:{base,base-dev,tool-*-latest,latest,YYYY.MM}`
  tags and their `cache-*` manifests are untouched for the entire effort. Aborting costs registry
  garbage and nothing else.
- **The noble image can be re-assembled without rebuilding anything:**
  `DEPS_FROM_TARGETS=0 ./build-images.sh` pulls the existing noble tool images straight from the
  registry — the documented purpose of that variable (`docker-bake.hcl:31-35`).
- **Work on a branch off `next_release`**: `ubuntu-26.04-upgrade` exists since 2026-11-09,
  cut from `44d1084a`. Never use or merge into `nightly`, the nightly workflow force-resets it
  from `next_release`. `next_release` keeps moving (tool bumps, workarounds), so rebase the
  branch regularly and re-grep the anchors in this plan after each rebase. Tag the merge-base
  (`git tag pre-resolute`) before Phase A. Reverting `_build/images/base/Dockerfile:7` plus the Phase A commit restores a
  buildable 24.04 tree; Phase C being one commit per workaround means any single workaround can
  come back on its own.
- **Point of no return** is the first `./build-all.sh` — it pushes `latest` and `YYYY.MM` to the
  public prefix and builds the devcontainer. Do not run it until the full `_tests` suite is green
  on both arches; use `DOCKER_TAGS=resolute-test ./build-images.sh` for everything before that.
- Commits stay local per the usual convention; publishing is Harald's call.

---

## Effort

Phase 0 is under an hour. Phases A–B are a day of iteration. Phase D dominates: ~50 tools ×
2 arches, with a full cold multi-arch build already documented as "several hours"
(`KNOWN_ISSUES.md:180`), plus however many of the CMake 4 / GCC 15 failure classes actually
land. A realistic estimate is **two to four weeks of elapsed time**, most of it build wall-clock
and per-tool triage rather than editing.

The main open risk after Phase 0 is `gdspy==1.6.13`: it is the last release of an
upstream-declared maintenance-only project tested to Python 3.8, so if its C extension does not
compile on 3.14 there is no newer pin to move to and the choice narrows to patching it,
vendoring a build, or dropping it.
