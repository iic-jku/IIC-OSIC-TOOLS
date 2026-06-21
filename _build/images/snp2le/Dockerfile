# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Install snp2le (S-parameter to lumped-element netlist converter)
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS snp2le
ARG SNP2LE_REPO_URL="https://github.com/iic-jku/snp2le.git"
# ToDo: update
ARG SNP2LE_REPO_COMMIT="e0af3048e0051f582740013908981f6e9ffaf21a"
ARG SNP2LE_NAME="snp2le"
RUN --mount=type=bind,source=images/snp2le,target=/images/snp2le \
    bash /images/snp2le/scripts/install.sh
