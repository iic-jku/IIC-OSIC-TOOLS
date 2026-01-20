# IIC-OSIC-TOOLS AI Agent Instructions

## Project Overview

IIC-OSIC-TOOLS is a comprehensive Docker/Podman-based container distribution for open-source IC design tools, supporting both analog and digital flows. It packages 80+ EDA tools with multiple Process Development Kits (PDKs) for both x86_64/amd64 and aarch64/arm64 architectures, based on Ubuntu 24.04 LTS.

**Key directories:**
- `_build/`: Multi-stage Docker build system with tool images and build orchestration
- `_tests/`: Regression test suite (18 tests covering PDKs, tools, and workflows)
- Root scripts: Container startup scripts for VNC, X11, Jupyter, and shell modes

## Architecture & Build System

### Multi-Stage Build Process

The build uses **docker buildx** with multi-architecture support across distributed build machines:

1. **Base images**: `base` (runtime) and `base-dev` (build dependencies) from `_build/images/base/`
2. **Tool images**: Each tool has a Dockerfile in `_build/images/<tool>/` (e.g., `magic`, `yosys`, `klayout`)
3. **Final image**: `_build/images/iic-osic-tools/` combines all tools with PDKs

**Build orchestration** (sequential execution required):
```bash
./builder-create.sh   # Creates buildx builder with remote SSH contexts
./build-base.sh       # Builds base and base-dev images
./build-tools.sh      # Builds tool images in 3 levels (handles dependencies)
./build-images.sh     # Assembles final image and pushes to registry
```

**Critical conventions:**
- `tool_metadata.yml`: Single source of truth for tool versions (git commit hashes)
- `docker-bake.hcl`: Docker Bake configuration defining targets, platforms, and cache strategies
- Tools are organized in dependency levels (`tools-level-1`, `tools-level-2`, `tools-level-3`)
- Each tool Dockerfile uses multi-stage builds to minimize final image size

### Builder Configuration

- Remote build machines: `buildx86` (amd64) and `buildaarch` (arm64) via passwordless SSH
- Custom builder name: `tools-builder-$USER`
- Registry: `registry.iic.jku.at:5000` for intermediate images, DockerHub (`hpretl/iic-osic-tools`) for distribution
- Set `DRY_RUN=1` on any build script to preview commands without execution

## PDK Management

Three PDKs are pre-installed with automatic environment setup:

**Switching PDKs**: Use `sak-pdk <pdk-name>` (not raw export commands)
```bash
sak-pdk sky130A                    # SkyWater 130nm
sak-pdk gf180mcuD                  # GlobalFoundries 180nm  
sak-pdk ihp-sg13g2                 # IHP 130nm SiGe BiCMOS (default)
```

The script sets: `PDK`, `PDKPATH`, `STD_CELL_LIBRARY`, `SPICE_USERINIT_DIR`, `KLAYOUT_PATH`

**Per-project PDK config**: Create `$DESIGNS/.designinit` with environment overrides (auto-sourced on container start)

## Developer Workflows

### Container Launch Modes

Scripts in repository root (`.sh` for Linux/macOS, `.bat` for Windows):

- `start_vnc.sh`: Full XFCE desktop via VNC/noVNC (port 80, password: abc123)
- `start_x.sh`: Direct X11 forwarding to host X server
- `start_shell.sh`: Shell-only access (runs as root by default)
- `start_jupyter.sh`: Jupyter notebook server

**Environment variables** (set before running scripts):
- `DESIGNS`: Host directory mounted to `/foss/designs` (default: `$HOME/eda/designs`)
- `DOCKER_USER`, `DOCKER_IMAGE`, `DOCKER_TAG`: Image selection
- `WEBSERVER_PORT`, `VNC_PORT`: Port mappings
- `DRY_RUN`: Print commands without execution

### Testing Strategy

Run tests inside container with `_tests/run_docker_tests.sh` or individually:
```bash
cd _tests/01 && ./test_librelane_sky130a.sh
```

Tests verify: LibreLane RTL2GDS flows, DRC/LVS, SPICE simulation, RISC-V toolchain, Python packages, etc.

**Test naming**: `_tests/NN/test_<description>_<pdk>.sh` where NN is test number (see `_tests/TESTS.md`)

### Key Tool Commands

- **LibreLane**: `librelane <config.json>` (RTL to GDS digital flow, successor to OpenLane)
- **OpenROAD**: Use `openroad` (latest) or `openroad-librelane` (older version for LibreLane compatibility)
- **Magic**: `magic -T <tech>` for layout editing (tech files in `$PDKPATH/libs.tech/magic/`)
- **Netgen**: `netgen -batch lvs` for LVS checking
- **ngspice**: Auto-loads PDK models from `$SPICE_USERINIT_DIR`
- **Xyce**: Use alias `xyce` which preloads IHP PSP103 plugin for SG13G2

## Critical Implementation Details

### Tool Installation Pattern

Each tool's `_build/images/<tool>/scripts/install.sh`:
1. Clones from git using commit from `tool_metadata.yml`
2. Builds/installs to `/foss/tools/<tool>` (shared via volume in multi-stage)
3. Updates `tool_metadata.yml` with actual commit used

### Environment Setup

`_build/images/base/skel/etc/profile.d/iic-osic-tools-setup.sh`:
- Sourced on container start, sets up PATH, PYTHONPATH, LD_LIBRARY_PATH
- Initializes default PDK (ihp-sg13g2)
- Defines helper functions like `_path_add_tool`, `_add_resolution` (VNC display modes)
- Sources `$DESIGNS/.designinit` last for user overrides

### Python Environment

- System Python 3.12 with extensive EDA packages (see `_build/images/base/Dockerfile`)
- Tools with Python bindings: ngspyce, pyopus, gdsfactory, cocotb, amaranth, etc.
- `PYTHONPATH` includes Yosys, KLayout, OpenEMS python modules

## Common Pitfalls

1. **Don't run build scripts as root**: Follow Docker post-install for non-root execution
2. **PDK switching**: Always use `sak-pdk`, not manual exports (sets 6+ environment variables correctly)
3. **Tool version conflicts**: OpenROAD has two versions; LibreLane wrapper auto-selects `openroad-librelane`
4. **Multi-arch builds**: Ensure both build machines (`buildx86`, `buildaarch`) are accessible before `builder-create.sh`
5. **Image size**: Final image is ~20GB extracted; clear unused images periodically with `docker image prune`
6. **Registry access**: Local registry needs `"insecure-registries"` in `/etc/docker/daemon.json` if using HTTP

## Project-Specific Patterns

- **Start script customization**: Set shell variables before running (e.g., `DESIGNS=/my/path ./start_vnc.sh`)
- **Version tagging**: Images tagged as `YYYY.MM` and `latest` (see `_build/build-all.sh`)
- **SAK scripts**: Bash utilities in `$TOOLS/sak/` (Swiss Army Knife), e.g., `sak-pdk-script.sh`, `sak-pex.sh`
- **Tool wrappers**: Some tools have wrapper scripts that set environment or select versions (see `librelane`, `xyce` aliases)

## File Organization

- **Dockerfiles**: `_build/images/<component>/Dockerfile` (base, tools, final)
- **Install scripts**: `_build/images/<tool>/scripts/install.sh` (tool-specific build logic)
- **Skeleton files**: `_build/images/base/skel/` (copied to container at `/`, includes config files)
- **Examples**: `_build/images/iic-osic-tools/skel/foss/examples/` (demo projects for sky130A, gf180mcuD)

## External References

- Tool list & versions: `README.md` section 3 and `tool_metadata.yml`
- Release history: `RELEASE_NOTES.md`
- Known issues: `KNOWN_ISSUES.md`
- Build details: `_build/README.md`
