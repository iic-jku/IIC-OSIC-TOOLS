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
ARG BENDER_REPO_COMMIT="c16584961d78f36867bce5b0912399683372c58a"
ARG SV2V_REPO_URL="https://github.com/zachjs/sv2v.git"
ARG SV2V_REPO_COMMIT="493a88f930802da68f592c192ec86991eaf95c49"
RUN --mount=type=bind,source=images/pulp-tools,target=/images/pulp-tools \
    bash /images/pulp-tools/scripts/install.sh
