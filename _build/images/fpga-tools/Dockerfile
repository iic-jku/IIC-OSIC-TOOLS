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
ARG ICESTORM_REPO_COMMIT="1fb7443c7c6870fadc275066c19af9c5add3482a"
ARG PRJTRELLIS_REPO_URL="https://github.com/YosysHQ/prjtrellis.git"
ARG PRJTRELLIS_REPO_COMMIT="65fe191a290cd947c125f011e9e78a2ddc90d7a4"
ARG NEXTPNR_REPO_URL="https://github.com/YosysHQ/nextpnr.git"
ARG NEXTPNR_REPO_COMMIT="3edea68ef37eddbe9fc4556de7d51ba08af201a0"
RUN --mount=type=bind,source=images/fpga-tools,target=/images/fpga-tools \
    bash /images/fpga-tools/scripts/install.sh
