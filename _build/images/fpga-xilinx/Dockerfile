# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile the openXC7 toolchain (prjxray, nextpnr-xilinx) for Xilinx
# 7-series FPGAs
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS fpga-xilinx
ARG FPGA_XILINX_NAME="fpga-xilinx"
# prjxray-db families to ship (the database dominates the image size, roughly
# 180/215/64/259 MB for artix7/kintex7/spartan7/zynq7). virtex7 is always
# dropped, the chipdb generation cannot map its parts.
ARG FPGA_XILINX_FAMILIES="artix7 kintex7 spartan7 zynq7"
ARG PRJXRAY_REPO_URL="https://github.com/f4pga/prjxray.git"
ARG PRJXRAY_REPO_COMMIT="c9f02d8576042325425824647ab5555b1bc77833"
ARG NEXTPNR_XILINX_REPO_URL="https://github.com/openXC7/nextpnr-xilinx.git"
ARG NEXTPNR_XILINX_REPO_COMMIT="68aeeb39f92e39bfb239c7e4a44dd93451fc1889"
RUN --mount=type=bind,source=images/fpga-xilinx,target=/images/fpga-xilinx \
    bash /images/fpga-xilinx/scripts/install.sh
