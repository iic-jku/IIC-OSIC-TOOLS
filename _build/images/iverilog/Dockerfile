# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile iverilog
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS iverilog
ARG IVERILOG_REPO_URL="https://github.com/steveicarus/iverilog.git"
ARG IVERILOG_REPO_COMMIT="5d04888549a177bd49b2a0ee4effcb1337fb0613"
ARG IVERILOG_NAME="iverilog"
RUN --mount=type=bind,source=images/iverilog,target=/images/iverilog \
    bash /images/iverilog/scripts/install.sh
