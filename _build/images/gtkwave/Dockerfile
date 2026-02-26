#######################################################################
# Compile gtkwave
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS gtkwave
ARG GTKWAVE_REPO_URL="https://github.com/gtkwave/gtkwave.git"
ARG GTKWAVE_REPO_COMMIT="c57c99773c8c1e3f984683995f078b0165a40f5e"
ARG GTKWAVE_NAME="gtkwave"
RUN --mount=type=bind,source=images/gtkwave,target=/images/gtkwave \
    bash /images/gtkwave/scripts/install.sh
