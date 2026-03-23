#######################################################################
# Compile gtkwave
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS gtkwave
ARG GTKWAVE_REPO_URL="https://github.com/gtkwave/gtkwave.git"
ARG GTKWAVE_REPO_COMMIT="1dbe6d02196f5badd13a25adb02a19a11e7dd2eb"
ARG GTKWAVE_NAME="gtkwave"
RUN --mount=type=bind,source=images/gtkwave,target=/images/gtkwave \
    bash /images/gtkwave/scripts/install.sh
