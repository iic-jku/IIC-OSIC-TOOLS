# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile pyopus
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS pyopus
ARG PYOPUS_REPO_URL="https://codeberg.org/arpadbuermen/PyOPUS.git"
ARG PYOPUS_REPO_COMMIT="f4f793c7387b248ceca9b5fc81b41bc5499a8626"
ARG PYOPUS_NAME="pyopus"
RUN --mount=type=bind,source=images/pyopus,target=/images/pyopus \
    bash /images/pyopus/scripts/install.sh
