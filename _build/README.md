<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../_logo/svg/logo-horizontal-reversed.svg">
    <source media="(prefers-color-scheme: light)" srcset="../_logo/svg/logo-horizontal.svg">
    <img src="../_logo/svg/logo-horizontal.svg" alt="IIC-OSIC-TOOLS" width="480">
  </picture>
</p>

# IIC-OSIC-TOOLS (Build Instructions)

**ATTENTION:** Building such a large SW stack with many, *many* dependencies for multiple architectures is time-consuming and nerve-wracking! Please only attempt this with experience in Linux and SW builds (`./configure && make && make install` should not be a mystery, as a minimum).

## Details for Developers and Contributors

### Quick Start Instructions for Using New Build Setup

#### Step 1: Create builders

```bash
./builder-create.sh
```

If the username is different on the build machines from the local machine, or different build machines should be used, then a `BUILDER_STRS` can be supplied:

```bash
BUILDER_STRS="host=ssh://$USER@buildx86,host=ssh://$USER@buildaarch"
```

The builders use hostnames `buildx86` (for `x86_64`/`amd64` build) and `buildaarch` (for `aarch64`/`arm64` build); they need to be able to be reached by passwordless SSH.

If just the local username differs from the username on the build machines, then the following can be used:

```bash
USER=otheruser ./builder-create.sh
```

To use a local image from a registry without HTTPS, the following entry has to be added to the Docker configuration file (e.g., `/etc/docker/daemon.json`):

```json
{
  "insecure-registries": ["registry.iic.jku.at:5000"]
}
```

#### Step 2: Build everything

```bash
./build-all.sh
```

`docker-bake.hcl` declares every inter-image dependency as a named build context
bound to a bake target, so this is a single `docker buildx bake all` run: BuildKit
knows the complete dependency graph and starts each image as soon as *its own*
dependencies are ready, rather than waiting for a whole dependency level to
finish. Ordering is derived from the graph and cannot go stale.

The individual steps below still work and can be used to build only a part of the
tree. They no longer have to run in a particular order — each one pulls in
whatever it needs.

```bash
./build-base.sh                       # base only
./build-base-dev.sh                   # base-dev only
./build-tools.sh                      # all tool images
./build-target.sh xschem              # a single target and its dependencies
DOCKER_PREFIXES="hpretl,registry.iic.jku.at:5000" DOCKER_TAGS="latest" ./build-images.sh
```

Use `DRY_RUN=1` on any of them to print the commands without executing them.

##### Build variables

These are read from the environment by `docker buildx bake`:

| Variable | Default | Effect |
| --- | --- | --- |
| `DEPS_FROM_TARGETS` | `1` | Resolve inter-image dependencies to bake targets (one DAG). Set to `0` to resolve them to the images already pushed to the registry, e.g. to re-tag and re-push the final image without rebuilding or re-checking any tool. |
| `CACHE_EXPORT` | `1` | Export a dedicated `mode=max` registry cache per target. Set to `0` when building without write access to the cache registry. |
| `REGISTRY` | `registry.iic.jku.at:5000` | Registry used for the intermediate and cache images. |
| `IMAGE` | `iic-osic-tools` | Repository name used for the intermediate and cache images. |
| `PLATFORMS` | `linux/amd64,linux/arm64` | Target platforms. |

##### Build cache

Every target imports from a dedicated cache manifest (`<registry>/<image>:cache-<target>`)
and falls back to the inline cache embedded in its own published image. Cache is
exported to both, with `mode=max` on the registry manifest so that intermediate
stages and `RUN --mount=type=cache` mounts are preserved as well. The cache
export uses `ignore-error=true`, so a read-only or unreachable registry degrades
to a slower build instead of a failed one.

The `cache-*` tags can be dropped at any time to reclaim registry space; the next
build then falls back to the inline caches.

To test locally stored images, the following command can be used:

```bash
DOCKER_USER=registry.iic.jku.at:5000 DOCKER_TAG=next ./start_shell.sh
```

### Nightly build

`.github/workflows/nightly.yaml` runs every night at 23:00 UTC on GitHub-hosted runners, and can be started by hand:

```bash
gh workflow run nightly.yaml                                          # same as the scheduled run
gh workflow run nightly.yaml -f skip_tests=true                       # build and publish only
gh workflow run nightly.yaml -f base_ref=my-branch -f skip_bump=true  # build another branch as it is
```

What one run does:

1. Resets branch `nightly` from `next_release` (input `base_ref`), runs `check_eda_tool_version.py -u`, `check_yaml_tool_version.py -u` and `rev_from_yaml.py`, commits the bumps and force-pushes `nightly`. Held pins stay (see "Version bumps" in `AGENTS.md`).
2. Builds every bake target natively on `ubuntu-24.04` (amd64) and `ubuntu-24.04-arm` (arm64), one target per job, level by level. `_build/tools/bake_levels.py` derives the levels from the named contexts of `docker-bake.hcl`. Each architecture has its own GHCR package, `ghcr.io/iic-jku/iic-osic-tools-nightly-<arch>`, holding the intermediate images and the build cache (`REGISTRY`, `IMAGE`, `PLATFORMS` and `DEPS_FROM_TARGETS=0` set through the environment).
3. Publishes both `image-full` images as the multi-arch tag `ghcr.io/iic-jku/iic-osic-tools:nightly`.
4. Runs `_tests/run_integration_tests.sh` on that tag on both architectures.
5. Reports. A failure opens the issue labelled `nightly-failure`, or comments on the open one, and turns the nightly PR into a draft. A green night with bumps opens or refreshes the PR `nightly` -> `next_release` and closes the failure issue. The workflow never merges.

The workflow file has to be on `main`, because GitHub runs scheduled and dispatched workflows from the default branch. It checks out `next_release` itself, so the helpers it calls come from there.

One-time setup: under Settings, Actions, General, set the workflow permissions to "Read and write" and allow GitHub Actions to create pull requests. After the first run, make the three GHCR packages public (the intermediates are tens of GB, public packages do not count against storage).

### Prerequisites

* [Docker](https://docs.docker.com/engine/install/)

### Building the container

The installation slightly differs from the original `foss-asic-tools` installation by efabless.com. For this image, the build is replaced with a single Dockerfile for convenience when doing a multi-architecture build. For a basic single (native)-architecture build, just run the following:

```bash
docker build .
```

You can add build parameters accordingly. We strongly recommend using `docker buildx` because of `buildkit` (parallel building) and multi-architecture support. The script `build_all.sh` includes building with `buildx` on two different machines (for fast `amd64` and `arm64` builds) and pushes both images to the Docker Hub under the same tag. The script includes multiple environment variables with defaults. If you intend to build this image, we encourage you to use this script as a template.
The predefined settings are for the ICD build machines, and the image gets pushed with the tags `latest` and `year.month` (e.g., `2022.12`).

### Detailed container settings

For specific use cases, the containers can be started without the help of the start scripts. Here are a few things to note down:

#### Environment Variables

The container makes use of several environment variables to control the behavior. **WARNING:** Those values may impact the functionality of the container. Do not change them unless you know what you are doing.

The internal VNC and web server ports are defined by environment variables (not to be confused with the variables in the start script; those manage the external ports, to which the Docker daemon maps the ports! It works *best* if those are matched). Those are used in the Dockerfile for the exposed ports and the configuration of the services.

* `VNC_PORT=5901` The default internal VNC port.
* `NO_VNC_PORT=80` The default internal web server port.

Furthermore, the following variables can be set:

* `HOME=/headless` sets the home directory in the container.
* `TERM=xterm` is the default graphical terminal emulator.
* `STARTUPDIR=/dockerstartup` is the directory in which all container-related scripts are put.
* `NO_VNC_HOME=/dockerstartup/noVNC` is the directory for the noVNC installation.
* `VNC_COL_DEPTH=24` VNC color resolution.
* `VNC_RESOLUTION=1680x1050` VNC display resolution. NOTE: This can also be changed while running in the desktop environment by going to Settings->Display.
* `VNC_PW=abc123` Default VNC password.
* `VNC_VIEW_ONLY=false` can set the VNC server to view only.
* `DESIGNS=/foss/designs` Default directory, where the user's designs are placed.
* `TOOLS=/foss/tools` Default tools directory.
* `PDK_ROOT=/foss/pdks` Default PDKs directory.

#### Entrypoint script

The entry point for this container is the [ui_startup.sh](https://github.com/iic-jku/iic-osic-tools/blob/main/_build/images/base/skel/dockerstartup/scripts/ui_startup.sh) script. It controls which kind of UI (Xvnc or connecting to local X11 server) is used. The control logic for the automatic mode is simple. If the environment variable `DISPLAY` is set, an existing X11 server is assumed, and the startup script runs an XFCE4 terminal. If the `DISPLAY` is not set, it starts Xvnc and the noVNC web interface. This behavior can be overwritten with command-line arguments.

The following command-line arguments are supported:

* `-X, --x11` Force to use local X11 forwarding requires a working combination of `$DISPLAY` and either port forwards or mounted `XAUTHORITY` and `.X11_unix` sockets.
* `-V, --vnc` Force use of VNC server, with noVNC and `websockify`.
* `-w, --wait` Runs the selected UI and waits for them to exit. The script will only return then. This flag is set in the container by default (via `CMD` in the Dockerfile).
* `-s, --skip` Skip the UI startup and execute the assigned command. **WARNING:** This must be the first parameter to the script, or it must be ignored! Example: `docker run hpretl/iic-osic-tools --skip bash`
* `-d, --debug` Enables more detailed startup output, e.g., `docker run hpretl/iic-osic-tools --debug`

As some examples already show, these parameters can be passed to the container via Docker:

```bash
docker run -it hpretl/iic-osic-tools:latest --wait --vnc
```

## Notes

* Each tool has a separate directory in the `images` directory with the build script and additional required files.
* The tool versions (typically the commit hash) have defaulted in the Dockerfile. It can be overwritten via environment variables.
* Only the final image is tagged; the sub-tools are not. It is still possible to build only to a certain stage (stages are defined in the Dockerfile by `FROM base_image as stage_name`).
* The final image is called `iic-osic-tools` by default.
* Docker on Windows suffers from bad memory management due to WSL2, especially for systems with less than 16 GB RAM. As a workaround, a memory limit to WSL can be set. See [Advanced settings configuration in WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) (look for the key “memory” in the `wsl2` tag).

## Todo

n/a
