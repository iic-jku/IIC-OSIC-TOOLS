#######################################################################
# Compile libman
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS libman
ARG LIBMAN_REPO_URL="https://github.com/IHP-GmbH/LibMan.git"
ARG LIBMAN_REPO_COMMIT="fe636d553c185d9983087de600276ab05e611182"
ARG LIBMAN_NAME="libman"
RUN --mount=type=bind,source=images/libman,target=/images/libman \
    bash /images/libman/scripts/install.sh
