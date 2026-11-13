# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Install KQCircuits sources
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS kqcircuits
ARG KQCIRCUITS_REPO_URL="https://github.com/iqm-finland/KQCircuits.git"
ARG KQCIRCUITS_REPO_COMMIT="b3ed0cebfe5d5922f3484aabd32aed452b8433ea"
ARG KQCIRCUITS_NAME="kqcircuits"
RUN --mount=type=bind,source=images/kqcircuits,target=/images/kqcircuits \
    bash /images/kqcircuits/scripts/install.sh
