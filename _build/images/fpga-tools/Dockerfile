# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile FPGA tools (icestorm, prjtrellis, nextpnr) prepared for
# Lattice iCE40 and Lattice ECP5
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS fpga-tools
ARG FPGA_NAME="fpga"
ARG ICESTORM_REPO_URL="https://github.com/YosysHQ/icestorm.git"
ARG ICESTORM_REPO_COMMIT="ee340bb2cec60e0d01948076537a9bb3d08aea26"
ARG PRJTRELLIS_REPO_URL="https://github.com/YosysHQ/prjtrellis.git"
ARG PRJTRELLIS_REPO_COMMIT="a31ff7042e712c0e2ad217054116ce2c4995f5c7"
ARG NEXTPNR_REPO_URL="https://github.com/YosysHQ/nextpnr.git"
ARG NEXTPNR_REPO_COMMIT="9691ce8c43fa49cfa38c68778fdeb14bf7e4ca82"
RUN --mount=type=bind,source=images/fpga-tools,target=/images/fpga-tools \
    bash /images/fpga-tools/scripts/install.sh
