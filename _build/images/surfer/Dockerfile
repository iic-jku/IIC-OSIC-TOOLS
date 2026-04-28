# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile surfer
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS surfer
ARG SURFER_REPO_URL="https://gitlab.com/surfer-project/surfer.git"
ARG SURFER_REPO_COMMIT="v0.7.0"
ARG SURFER_NAME="surfer"
RUN --mount=type=bind,source=images/surfer,target=/images/surfer \
    bash /images/surfer/scripts/install.sh
