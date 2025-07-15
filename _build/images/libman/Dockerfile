#######################################################################
# Compile libman
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS libman
ARG LIBMAN_REPO_URL="https://github.com/IHP-GmbH/LibMan.git"
ARG LIBMAN_REPO_COMMIT="09ff4bac10bd6f47c432579c25f9b39d4f44bb47"
ARG LIBMAN_NAME="libman"
USER 0:0
RUN --mount=type=bind,source=images/libman,target=/images/libman \
    bash /images/libman/scripts/install.sh
