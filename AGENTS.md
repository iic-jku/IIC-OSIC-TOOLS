# Repository conventions

Guidance for coding agents and contributors working in this repo (the IIC-OSIC-TOOLS container image of open-source IC design tools).

This file holds the essentials. The detail lives in existing docs, read the one that fits the task:

- `.github/copilot-instructions.md`: architecture overview, PDK switching with `sak-pdk`, start-script variables, the environment inside the container.
- `_build/README.md`: builder setup, bake variables, build cache, entrypoint flags of the container.
- `_tests/TESTS.md`: test list, container engine choice, where test output goes, scheduling.
- `.claude/skills/prepare-image-release/SKILL.md`: the monthly release procedure (release notes, known issues, removable workarounds). It is a plain Markdown procedure, follow it step by step whatever tool you use.
- `README.md`: user documentation. Section 3 is the public tool list.

## What the repo builds

- One multi-arch image (`linux/amd64`, `linux/arm64`) on Ubuntu 24.04 (`ubuntu:noble` in `_build/images/base/Dockerfile`), published as `hpretl/iic-osic-tools` with the tags `latest` and `YYYY.MM`.
- The repo holds no tool sources. Each tool is fetched at a pinned revision (mostly a git commit, a few release downloads such as `uv`) and built in its own image, and the final image copies the results together.

## Layout

- `_build/docker-bake.hcl`: all bake targets and groups (`all`, `tools`, `images`, `base`, `base-dev`, one target per tool, `image-full`).
- `_build/images/base/`: runtime base image. `_build/images/base-dev/`: build dependencies, parent of most tool images.
- `_build/images/<tool>/`: `Dockerfile` plus `scripts/install.sh`, installs into `$TOOLS/<tool>` (`/foss/tools/<tool>`). The bake target is named after the directory, except `fpga-tools`, whose target is `fpga`.
- `_build/images/open_pdks/`: PDK installation (sky130A and gf180mcuD through ciel, both IHP PDKs from git) and the install-time PDK fixups in `scripts/` and `patches/`.
- `_build/images/iic-osic-tools/`: the final image. Its `Dockerfile` copies `$TOOLS/<tool>` out of every tool image, and `skel/` is copied to `/` (SAK scripts in `skel/foss/tools/sak/`, pip, cargo and gem installs in `skel/headless/scripts/install_eda.sh`).
- `_build/tool_metadata.yml`: repo URL and pinned commit or tag per tool, shipped in the image as `/tool_metadata.yml`.
- `_build/tools/`: version helper scripts (see Version bumps). `_build/devcontainer/`: devcontainer image and template.
- `_tests/NN/`: one regression test per numbered directory, runner `_tests/run_integration_tests.sh`.
- Repo root: `start_{vnc,x,shell,jupyter}.{sh,bat}` (start a container on a user's machine), `install.{sh,ps1,bat}` (prerequisites installer), `eda_server_*.sh` (multi-user server), `RELEASE_NOTES.md`, `KNOWN_ISSUES.md`.

## Building

Run every build script from inside `_build/`: `docker buildx bake` reads `docker-bake.hcl` from the working directory, and `builder-create.sh` reads `./buildkitd.toml`.

```bash
cd _build
DRY_RUN=1 ./build-all.sh   # print the commands, run nothing (works on every build script)
./builder-create.sh        # buildx builder tools-builder-$USER, one node per platform
./build-target.sh xschem   # one bake target and whatever it depends on
./build-tools.sh           # all tool images
./build-all.sh             # base, base-dev, tools and final image as one DAG, then the devcontainer
```

- There is no single top-level Dockerfile. Build through the bake targets.
- The defaults point at the maintainers' own infrastructure: a registry (`REGISTRY` in `docker-bake.hcl`, `DOCKER_PREFIXES` in `build-all.sh` and `build-images.sh`) and two SSH build hosts (`BUILDER_STRS` in `builder-create.sh`). Without access, point these at your own builder and a registry you can push to, and set `CACHE_EXPORT=0`.
- The platform list has two names: `DOCKER_PLATFORMS` for `builder-create.sh` and `builder-clear.sh`, `PLATFORMS` for bake.
- `build-base.sh`, `build-base-dev.sh`, `build-tools.sh` and `build-target.sh` push their result unless `DOCKER_LOAD` is set, which switches them to `--load`. `build-images.sh` and `build-all.sh` always push. `NO_CACHE=1` adds `--no-cache` to `build-target.sh`.
- `DRY_RUN` and `DOCKER_LOAD` act on any value, so `DRY_RUN=0` is still a dry run. Unset them instead.
- Build order comes from the named contexts in `docker-bake.hcl`, not from the `tools-level-*` groups (kept for staged builds only). When a tool image gains or loses a `FROM ${TOOL_IMAGE_*}` or `COPY --from` on another tool image, update the `contexts` (`tooldep("<tool>")`) and `args` of its bake target in the same change.

## Adding a tool

A new tool touches the same files every time (precedent: commits `33d6fb6b` OpenCDC and `26d7dfe5` SVCK):

1. `_build/images/<tool>/Dockerfile` with `ARG <TOOL>_REPO_URL`, `ARG <TOOL>_REPO_COMMIT` and `ARG <TOOL>_NAME`, plus `scripts/install.sh`, which clones, checks out `${<TOOL>_REPO_COMMIT}`, installs to `${TOOLS}/${<TOOL>_NAME}` and writes `${TOOLS}/${<TOOL>_NAME}/SOURCES`. `_build/images/xschem/` is a compact template.
2. An entry in `_build/tool_metadata.yml`.
3. A target in `docker-bake.hcl`, listed in the `tools` group and the matching `tools-level-*` group, plus a context and an arg in `image-full`.
4. `ARG TOOL_IMAGE_<TOOL>`, a `FROM` line and a `COPY --link --from` line in `_build/images/iic-osic-tools/Dockerfile`.
5. A line in the tool list of `README.md` section 3.

Build-only packages go into `_build/images/base-dev/scripts/install.sh`, runtime libraries into `_build/images/base/scripts/00_base_install.sh`. Executables in `$TOOLS/<tool>/bin` are linked into `$TOOLS/bin` by `_build/images/iic-osic-tools/skel/headless/scripts/install_links.sh` at image build. Other `PATH`, `PYTHONPATH` and `LD_LIBRARY_PATH` entries go into `_build/images/base/skel/etc/profile.d/iic-osic-tools-setup.sh`.

## Version bumps

Pins live in three places. A bump commit changes the pin and the Dockerfiles together (e.g. `6d16a0c7`).

- Tool images: `_build/tool_metadata.yml` and the `ARG <TOOL>_REPO_COMMIT` lines in `_build/images/*/Dockerfile*` must agree. `<TOOL>` is the YAML `name` upper-cased, with `-` turned into `_`. A name that does not match is skipped without an error, so the two drift silently. One pin can sit in several Dockerfiles (`VACASK_REPO_COMMIT` is in `vacask` and `open_pdks`), and `rev_from_yaml.py` updates all of them.

```bash
cd _build
python3 tools/check_yaml_tool_version.py                # list newer upstream commits and tags
python3 tools/check_yaml_tool_version.py -u -t xschem   # write them into tool_metadata.yml (without -t: every tool)
python3 tools/rev_from_yaml.py --dry-run                # preview, then run without --dry-run to rewrite the Dockerfile ARGs
python3 tools/check_eda_tool_version.py                 # list newer pip, cargo and gem releases than pinned in install_eda.sh
python3 tools/check_eda_tool_version.py -u -t cocotb --dry-run   # preview, then run without --dry-run to write the pin (without -t: every package)
```

- Commit pins move to the head of the upstream default branch (or of the branch named by an optional `branch:` key, e.g. `openvaf`), tag pins to the newest tag with the same prefix. The helpers need PyYAML, and `check_eda_tool_version.py` also needs `requests` and `packaging`.
- pip, cargo and gem packages: pinned in `install_eda.sh`, checked and bumped with `check_eda_tool_version.py` (commands above). Its default input `_build/tool_eda.sh` is a git symlink to `install_eda.sh`. On a checkout without symlink support, pass `images/iic-osic-tools/skel/headless/scripts/install_eda.sh` explicitly.
- Comments next to a pin record why it is held (e.g. `cace` in `install_eda.sh`). Read them before bumping.
- The IHP PDKs are not pinned: `_build/images/open_pdks/scripts/install_ihp.sh` checks out branch `dev` of `iic-jku/IHP-Open-PDK`, so a rebuild can change them with no diff in this repo. sky130A and gf180mcuD follow `OPEN_PDKS_REPO_COMMIT` in `_build/images/open_pdks/Dockerfile`.

## Testing

`_tests/run_integration_tests.sh` runs on the host, not in the container. It takes the full image tag, starts one container (Podman if installed, else Docker, override with `CONTAINER_ENGINE`), mounts the current directory at `/foss/designs` and runs every `test*.sh` below it in parallel.

```bash
cd _tests
./run_integration_tests.sh hpretl/iic-osic-tools:latest
IIC_TEST_NO_PULL=1 ./run_integration_tests.sh <registry>/iic-osic-tools:<tag>   # a locally built image
```

- The runner pulls the tag first. For a locally built image set `IIC_TEST_NO_PULL=1`, or the pull replaces it with the registry image of the same tag.
- Output goes to `/tmp/iic-osic-tools-tests/<run-id>` (`IIC_TEST_RUNDIR` overrides it), never into the source tree. The work dir and log of a passing test are deleted when it finishes (`IIC_TEST_KEEP_PASSED=1` keeps them), the joblog and the data of failed tests stay after the run. Delete old run dirs by hand.
- On a terminal the runner shows a live progress line and prints only the failures, each with its log under `logs/` in the run dir. Redirected output and `IIC_TEST_PROGRESS=0` give the plain per-test output.
- A full run takes over an hour (test 28 alone ran 4356 s in the timing recorded in the runner). Each test is a standalone bash script, so in a container with the repo mounted one test runs directly, e.g. `bash _tests/05/test_ngspice_sg13g2.sh`.
- A new test goes into the next free `_tests/NN/` as `test_<what>_<pdk>.sh`. Model it on `_tests/05/test_ngspice_sg13g2.sh`: default `RAND`, write only below `${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}/$RAND/NN`, end with `[INFO] Test <name> passed.` or `[ERROR] Test <name> FAILED.` and the matching exit code, and gate extra output behind `DEBUG=1`. Add its row to `_tests/TESTS.md`, and add a long-running test to `SLOW_TESTS` in the runner.
- A workaround or PDK fixup should have a test that fails without it (e.g. `_tests/34` guards `open_pdks/scripts/fix_klayout_run_dir.py`). A change to the image counts as verified only after an image build and the affected tests pass.

## Conventions

- Work lands on `next_release`, and `main` receives it at the monthly release (tags `YYYY.MM`).
- Scripts and Dockerfiles start with the SPDX block used throughout the repo (`SPDX-FileCopyrightText`, `SPDX-License-Identifier: Apache-2.0`). Copy it from a neighboring file. Markdown files carry none.
- Build and install scripts use `set -e`. Messages start with `[INFO]`, `[WARNING]` or `[ERROR]`.
- The start scripts share most of their logic. A fix in one usually belongs in all four `.sh` scripts, and in the `.bat` twins where Windows behaves the same (e.g. `33a07842`). `DRY_RUN=1` prints their container commands instead of running them. Do not run the start or build scripts as root (README section 4).
- `_build/tool_eda.sh` and `sak/iic-*.sh` are git symlinks (the `iic-*` names are compatibility aliases of `sak-*`). Edit the target files and keep the links.
- A workaround carries a comment naming the upstream issue or commit it waits for, so the release pass can tell when it can go.
- Commit subjects are short and imperative (`Fix Spike build failing on -Werror with -Os`), the body says why.
- Release notes take one line per entry, `* [Tag] what changed for the user`. Tag order and what to leave out are in the release procedure file.

## Do not

- Do not push or retag images, and do not run the workflows in `.github/workflows/` (both publish devcontainer artifacts), unless asked. Check a build command with `DRY_RUN=1` first.
- Do not change a pin in only one of `tool_metadata.yml` and the Dockerfiles.
- Do not drop a workaround because an upstream issue is closed. The fix must be in the revision the image builds (see the release procedure file).
- Do not commit test leftovers. An aborted run can leave `_run_tests_<id>.sh` in the directory the runner was started from.
- Do not hard-code counts of tests or tools in docs, they go stale.

## Writing style

These rules apply to documentation, code comments, commit messages, and pull request descriptions in this repo.

- No em-dashes, no double-hyphen dashes, and no semicolons in prose. Code is exempt. Use commas, colons, periods, or parentheses, and split long sentences instead.
- Plain, factual tone: numbers, paths, and verdicts over adjectives, no filler.
- Never hard-wrap prose at a fixed column. Put each sentence or paragraph on one line and let the editor wrap it. When editing, never reflow neighboring lines.
- Keep comments short and accurate: say what is non-obvious and why, never restate what the code already shows.
