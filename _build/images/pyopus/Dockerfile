# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile pyopus
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS pyopus
ARG PYOPUS_REPO_URL="https://codeberg.org/arpadbuermen/PyOPUS.git"
ARG PYOPUS_REPO_COMMIT="9b3c6ab584f87ac8efd857c6d6bd5c337e50f74a"
ARG PYOPUS_NAME="pyopus"
RUN --mount=type=bind,source=images/pyopus,target=/images/pyopus \
    bash /images/pyopus/scripts/install.sh
