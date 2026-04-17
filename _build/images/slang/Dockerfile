# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile slang
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS slang
ARG SLANG_REPO_URL="https://github.com/MikePopoloski/slang.git"
ARG SLANG_REPO_COMMIT="777a6553fa3ddf9b2bfee4eaab8acbf27773b72c"
ARG SLANG_NAME="slang"
RUN --mount=type=bind,source=images/slang,target=/images/slang \
    bash /images/slang/scripts/install.sh
