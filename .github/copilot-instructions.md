# IIC-OSIC-TOOLS AI Agent Instructions

## Project Overview

IIC-OSIC-TOOLS is a comprehensive Docker/Podman-based container environment for open-source integrated circuit (IC) design, supporting both analog and digital workflows. The project provides 50+ EDA tools, multiple PDKs (sky130A, gf180mcuD, ihp-sg13g2), and runs on x86_64/amd64 and aarch64/arm64 architectures based on Ubuntu 24.04 LTS.

## Architecture

### Multi-Stage Docker Build System

- **Base images**: [`_build/images/base/`](_build/images/base/) and [`_build/images/base-dev/`](_build/images/base-dev/) provide Ubuntu foundation
- **Individual tool images**: Each tool in [`_build/images/`](_build/images/) (magic, ngspice, klayout, etc.) has its own Dockerfile
- **Three-level build hierarchy**: Tools are built in dependency order (level-1 → level-2 → level-3) as defined in [`_build/docker-bake.hcl`](_build/docker-bake.hcl)
- **Final image**: [`_build/images/iic-osic-tools/`](_build/images/iic-osic-tools/) aggregates all tools into the distribution container
- **Multi-arch support**: Uses `docker buildx` with remote builders for native x86_64 and arm64 compilation

### Key Directories

- [`_build/`](_build/): Complete build infrastructure and Dockerfiles
- [`_tests/`](_tests/): 18 regression tests validating tools and PDK workflows
- Root scripts (`start_*.sh`, `start_*.bat`): User-facing container launch scripts for VNC, X11, Jupyter, and shell modes

## Developer Workflows

### Building Images

```bash
# 1. Create multi-arch builders (one-time setup)
cd _build && ./builder-create.sh

# 2. Build base image
./build-base.sh

# 3. Build all tools (respects 3-level dependency order)
./build-tools.sh

# 4. Build and push final images with tags
DOCKER_PREFIXES="hpretl,registry.iic.jku.at:5000" DOCKER_TAGS="latest,2025.01" ./build-images.sh
```

Build scripts in [`_build/`](_build/) use environment variables:
- `BUILDER_NAME`: Custom buildx builder (default: `tools-builder-$USER`)
- `DOCKER_LOAD`: Use `--load` instead of `--push` for local testing
- `DRY_RUN`: Print commands without execution

### Testing

Run regression tests from [`_tests/`](_tests/):
```bash
# Inside container or via ./start_shell.sh
./_tests/run_docker_tests.sh
```

Tests validate: LibreLane RTL2GDS flows (tests 01, 04, 07, 18), DRC/LVS (02), ngspice simulation (05, 06, 11, 14), RISC-V toolchain (09), Verilator/iVerilog (12), and more. Test logs go to [`_tests/runs/`](_tests/runs/).

### PDK Management

The container includes three PDKs. Switch using the `sak-pdk` command (implemented in [`_build/images/iic-osic-tools/skel/foss/tools/sak/sak-pdk-script.sh`](_build/images/iic-osic-tools/skel/foss/tools/sak/sak-pdk-script.sh)):

```bash
sak-pdk sky130A              # SkyWater 130nm
sak-pdk gf180mcuD            # GlobalFoundries 180nm
sak-pdk ihp-sg13g2           # IHP SiGe:C BiCMOS 130nm
```

This sets `PDK`, `PDKPATH`, `STD_CELL_LIBRARY`, `SPICE_USERINIT_DIR`, and `KLAYOUT_PATH`. Default PDK is `ihp-sg13g2` (see [`_build/images/base/skel/etc/profile.d/iic-osic-tools-setup.sh`](_build/images/base/skel/etc/profile.d/iic-osic-tools-setup.sh#L82-L86)).

Projects can set PDK-specific variables in `.designinit` files placed in the `$DESIGNS` directory.

## Project Conventions

### Tool Metadata

[`_build/tool_metadata.yml`](_build/tool_metadata.yml) is the single source of truth for tool versions, specifying git repos and commit hashes for all 50+ tools. Update this file when upgrading tool versions.

### Container Environment Variables

Critical environment variables (from [`_build/README.md`](_build/README.md)):
- `TOOLS=/foss/tools`: Tool installation directory
- `DESIGNS=/foss/designs`: User design workspace (mounted from host)
- `PDK_ROOT=/foss/pdks`: PDK installation root
- `VNC_PORT=5901`, `NO_VNC_PORT=80`: Service ports
- `HOME=/headless`: Container home directory

### User Scripts and Aliases

The startup script ([`_build/images/base/skel/etc/profile.d/iic-osic-tools-setup.sh`](_build/images/base/skel/etc/profile.d/iic-osic-tools-setup.sh)) provides:
- Aliases: `tt` (→ `$TOOLS`), `dd` (→ `$DESIGNS`), `pp` (→ `$PDK_ROOT`), `k` (→ `klayout`), `ke` (→ `klayout -e`)
- Tool-specific overrides: `xyce` alias loads IHP PSP103 plugin, `surfer` sets `LIBGL_ALWAYS_INDIRECT=0`
- Path setup for Python packages, KLayout, and custom tools

### Start Scripts

User-facing scripts (`start_vnc.sh`, `start_x.sh`, `start_jupyter.sh`, `start_shell.sh`) support customization via environment variables:
- `DESIGNS`: Host directory to mount (default: `$HOME/eda/designs`)
- `DOCKER_USER`, `DOCKER_IMAGE`, `DOCKER_TAG`: Image selection
- `WEBSERVER_PORT`, `VNC_PORT`: Port mappings (0 disables)
- `DRY_RUN`: Print Docker commands instead of executing

Windows users have equivalent `.bat` scripts with `%USERPROFILE%` defaults.

## Integration Points

### Build System Dependencies

- **Docker Buildx**: Required for multi-arch builds; configured in [`_build/buildkitd.toml`](_build/buildkitd.toml)
- **Remote builders**: Scripts expect SSH-accessible build hosts named `buildx86` and `buildaarch`
- **Registry**: Internal registry `registry.iic.jku.at:5000` used for intermediate tool images; requires `insecure-registries` config for HTTP access

### External Tool Sources

All tools are built from source (no apt packages for EDA tools). Sources are cloned from GitHub/GitLab during Docker build phases. Build failures typically trace to:
1. Upstream API changes (check commit in [`tool_metadata.yml`](_build/tool_metadata.yml))
2. Missing build dependencies in base image
3. Architecture-specific compilation issues (arm64 vs x86_64)

### Container Modes

Four operational modes documented in [`README.md`](README.md#1-how-to-use-these-open-source-and-free-ic-design-tools):
1. **VNC/noVNC**: Full XFCE desktop in browser (recommended for remote use)
2. **X11 forwarding**: Direct window display on host (requires X server on macOS/Windows)
3. **Jupyter**: Notebook server for Python-based workflows
4. **Dev container**: VS Code integration via [`_build/devcontainer/`](_build/devcontainer/)

## Critical Patterns

### Testing New Tools

When adding a tool to [`_build/images/`](_build/images/):
1. Create `images/newtool/Dockerfile` following existing patterns
2. Add entry to [`tool_metadata.yml`](_build/tool_metadata.yml) with repo and commit
3. Add target to [`docker-bake.hcl`](_build/docker-bake.hcl) in appropriate level group
4. Update [`README.md`](README.md#3-installed-tools) tool list
5. Create regression test in [`_tests/`](_tests/) if applicable

### PDK-Specific Code

Tools using PDK paths must:
- Check `$PDK` and `$PDKPATH` environment variables
- Support switching via `sak-pdk` (avoid hardcoding PDK names)
- Place tech files under `$PDKPATH/libs.tech/<tool>/`

Example from [`_build/images/iic-osic-tools/skel/foss/tools/sak/sak-drc.sh`](_build/images/iic-osic-tools/skel/foss/tools/sak/sak-drc.sh#L247): `magic -rcfile "$PDKPATH/libs.tech/magic/$PDK.magicrc"`

### Mixed-Signal Co-Simulation

The container includes [spicebind](https://github.com/themperek/spicebind), a VPI-based bridge enabling co-simulation of analog ngspice circuits with HDL simulators (tested with Icarus Verilog). Usage pattern:
```bash
vvp -M $(spicebind-vpi-path) -m spicebind_vpi testbench.vvp
```
Requires environment variables: `SPICE_NETLIST`, `HDL_INSTANCE`, and optionally `VCC`. Supports multiple analog instances via comma-separated `HDL_INSTANCE` values.

### Version Tagging

Images follow `YYYY.MM` versioning (e.g., `2025.01`). Release process:
- Tag set via `CONTAINER_TAG` in [`build-images.sh`](_build/build-images.sh) (defaults to current month)
- Pushed with both `latest` and date tag to Docker Hub under `hpretl/iic-osic-tools`
- Update [`RELEASE_NOTES.md`](RELEASE_NOTES.md) with tool version changes from [`tool_metadata.yml`](_build/tool_metadata.yml)
