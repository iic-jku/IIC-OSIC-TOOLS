#######################################################################
# Compile gtkwave
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS gtkwave
ARG GTKWAVE_REPO_URL="https://github.com/gtkwave/gtkwave.git"
ARG GTKWAVE_REPO_COMMIT="e5eede91e06f48c22d46837ca66d701540365f97"
ARG GTKWAVE_NAME="gtkwave"
RUN --mount=type=bind,source=images/gtkwave,target=/images/gtkwave \
    bash /images/gtkwave/scripts/install.sh
