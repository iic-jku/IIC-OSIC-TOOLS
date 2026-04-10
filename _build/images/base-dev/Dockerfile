# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Add dev packages to base image 
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS base-dev
RUN --mount=type=bind,source=images/base-dev,target=/images/base-dev \
    bash /images/base-dev/scripts/install.sh
