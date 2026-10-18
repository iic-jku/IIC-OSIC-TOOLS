# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile libman
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS libman
ARG LIBMAN_REPO_URL="https://github.com/IHP-GmbH/LibMan.git"
ARG LIBMAN_REPO_COMMIT="27f3a63ffdbc1d57d5b67dddb749d53cb52d82b2"
ARG LIBMAN_NAME="libman"
RUN --mount=type=bind,source=images/libman,target=/images/libman \
    bash /images/libman/scripts/install.sh
