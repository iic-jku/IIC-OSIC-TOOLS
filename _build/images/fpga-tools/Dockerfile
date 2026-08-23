# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile FPGA tools (icestorm, prjtrellis, apycula, nextpnr) prepared
# for Lattice iCE40, Lattice ECP5 and Gowin
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS fpga-tools
ARG FPGA_NAME="fpga"
ARG ICESTORM_REPO_URL="https://github.com/YosysHQ/icestorm.git"
ARG ICESTORM_REPO_COMMIT="f31c39cc2eadd0ab7f29f34becba1348ae9f8721"
ARG PRJTRELLIS_REPO_URL="https://github.com/YosysHQ/prjtrellis.git"
ARG PRJTRELLIS_REPO_COMMIT="3afe7b52b30f4b4417ee98f03016767a502006e3"
ARG APYCULA_REPO_URL="https://pypi.org/project/apycula"
ARG APYCULA_REPO_COMMIT="0.32"
ARG NEXTPNR_REPO_URL="https://github.com/YosysHQ/nextpnr.git"
ARG NEXTPNR_REPO_COMMIT="7c0c1c40196fcca091320d06422a08749b106e53"
RUN --mount=type=bind,source=images/fpga-tools,target=/images/fpga-tools \
    bash /images/fpga-tools/scripts/install.sh
