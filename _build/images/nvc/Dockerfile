# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile nvc (VHDL simulator)
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS nvc
ARG NVC_REPO_URL="https://github.com/nickg/nvc.git"
ARG NVC_REPO_COMMIT="r1.20.0"
ARG NVC_NAME="nvc"
RUN --mount=type=bind,source=images/nvc,target=/images/nvc \
    bash /images/nvc/scripts/install.sh
