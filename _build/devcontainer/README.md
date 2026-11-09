# Devcontainer image

The subfolder `image/` holds the Docker image variant prepared for the [devcontainers](https://containers.dev/) infrastructure.

## Docker Image

The Docker image takes the IIC-OSIC-TOOLS Docker image as base and performs a
very minor operation: Properly creating the user directly. Later we might need
to add more devcontainer-specific support once we run into issues, or might
deprecate the image in case that the base image works directly.

The image is published to Docker Hub as `hpretl/iic-osic-tools-devcontainer`.

### Building

Run `build-devcontainer.sh` from the `_build/` directory (also included
in `build-all.sh`):

```bash
cd _build
./build-devcontainer.sh
```
