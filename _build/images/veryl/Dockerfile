# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile veryl
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS veryl
ARG VERYL_NAME="veryl"
RUN --mount=type=bind,source=images/veryl,target=/images/veryl \
    bash /images/veryl/scripts/install.sh
