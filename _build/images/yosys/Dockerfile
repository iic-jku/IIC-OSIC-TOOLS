# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile yosys & ghdl plugin & slang plugin
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS yosys
ARG YOSYS_REPO_URL="https://github.com/YosysHQ/yosys.git"
ARG YOSYS_REPO_COMMIT="v0.65"
ARG YOSYS_NAME="yosys"
ARG YOSYS_EQY_REPO_URL="https://github.com/YosysHQ/eqy.git"
ARG YOSYS_EQY_NAME="yosys_eqy"
ARG YOSYS_EQY_REPO_COMMIT="v0.64"
ARG YOSYS_SBY_REPO_URL="https://github.com/YosysHQ/sby.git"
ARG YOSYS_SBY_NAME="yosys_sby"
ARG YOSYS_SBY_REPO_COMMIT="v0.64"
ARG YOSYS_MCY_REPO_URL="https://github.com/YosysHQ/mcy.git"
ARG YOSYS_MCY_NAME="yosys_mcy"
ARG YOSYS_MCY_REPO_COMMIT="v0.64"
ARG YICES2_NAME="yices2"
ARG YICES2_REPO_URL="https://github.com/SRI-CSL/yices2.git"
ARG YICES2_REPO_COMMIT="b2f63a2816086419f079caf6dfbda93dd2d7c482"
RUN --mount=type=bind,source=images/yosys,target=/images/yosys \
    bash /images/yosys/scripts/install.sh
