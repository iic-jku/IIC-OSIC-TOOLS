# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile xcircuit
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS xcircuit
ARG XCIRCUIT_REPO_URL="https://github.com/RTimothyEdwards/XCircuit.git"
ARG XCIRCUIT_REPO_COMMIT="eab56ebad351650b4050fcde85cda9919844ed58"
ARG XCIRCUIT_NAME="xcircuit"
RUN --mount=type=bind,source=images/xcircuit,target=/images/xcircuit \
    bash /images/xcircuit/scripts/install.sh
