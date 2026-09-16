# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile openems
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS openems
ARG OPENEMS_REPO_URL="https://github.com/thliebig/openEMS-Project.git"
ARG OPENEMS_REPO_COMMIT="46169dec3e2e0a40a24858ac187cc5e15b0c4751"
ARG OPENEMS_NAME="openems"
RUN --mount=type=bind,source=images/openems,target=/images/openems \
    bash /images/openems/scripts/install.sh
