# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile pulp platform tools
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS pulp-tools
ARG PULP_NAME="pulp"
ARG BENDER_REPO_URL="https://github.com/pulp-platform/bender.git"
ARG BENDER_REPO_COMMIT="97b599b2d3cb433d204cf71b8583f6ec2825d509"
ARG SV2V_REPO_URL="https://github.com/zachjs/sv2v.git"
ARG SV2V_REPO_COMMIT="6662fa5da71f87797598060f17728b284b99a9fc"
RUN --mount=type=bind,source=images/pulp-tools,target=/images/pulp-tools \
    bash /images/pulp-tools/scripts/install.sh
