#######################################################################
# Compile verible
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS verible
ARG VERIBLE_REPO_URL="https://github.com/chipsalliance/verible.git"
ARG VERIBLE_REPO_COMMIT="v0.0-4053-g89d4d98a"
ARG VERIBLE_NAME="verible"
RUN --mount=type=bind,source=images/verible,target=/images/verible \
    bash /images/verible/scripts/install.sh
