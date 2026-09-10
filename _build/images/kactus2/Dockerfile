# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile kactus2
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS kactus2
ARG KACTUS2_REPO_URL="https://github.com/kactus2/kactus2dev.git"
ARG KACTUS2_REPO_COMMIT="v3.14.2"
ARG KACTUS2_NAME="kactus2"
RUN --mount=type=bind,source=images/kactus2,target=/images/kactus2 \
    bash /images/kactus2/scripts/install.sh
