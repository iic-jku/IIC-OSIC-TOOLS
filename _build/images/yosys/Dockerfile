# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile yosys & ghdl plugin & slang plugin
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS yosys
# Held back at v0.67: yosys v0.68 removed the "-fast" option from the "abc"
# pass, but LibreLane calls "abc -fast" unconditionally in its pyosys
# synthesis script, so every LibreLane flow dies in synthesis with v0.68.
# Upstream LibreLane has no fix yet (main still calls it), so bump this back
# to v0.68 (and eqy/sby/mcy with it) once it does.
ARG YOSYS_REPO_URL="https://github.com/YosysHQ/yosys.git"
ARG YOSYS_REPO_COMMIT="v0.67"
ARG YOSYS_NAME="yosys"
ARG YOSYS_EQY_REPO_URL="https://github.com/YosysHQ/eqy.git"
ARG YOSYS_EQY_NAME="yosys-eqy"
ARG YOSYS_EQY_REPO_COMMIT="v0.67"
ARG YOSYS_SBY_REPO_URL="https://github.com/YosysHQ/sby.git"
ARG YOSYS_SBY_NAME="yosys-sby"
ARG YOSYS_SBY_REPO_COMMIT="v0.67"
ARG YOSYS_MCY_REPO_URL="https://github.com/YosysHQ/mcy.git"
ARG YOSYS_MCY_NAME="yosys-mcy"
ARG YOSYS_MCY_REPO_COMMIT="v0.67"
ARG YICES2_NAME="yices2"
ARG YICES2_REPO_URL="https://github.com/SRI-CSL/yices2.git"
ARG YICES2_REPO_COMMIT="05178c03ddf49c6bba63c5c7153774c11a5da12d"
RUN --mount=type=bind,source=images/yosys,target=/images/yosys \
    bash /images/yosys/scripts/install.sh
