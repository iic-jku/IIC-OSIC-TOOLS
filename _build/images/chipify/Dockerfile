# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Install chipify
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS chipify
ARG CHIPIFY_REPO_URL="https://github.com/santihofi/chipify.git"
ARG CHIPIFY_REPO_COMMIT="18022f787933aa86c42a77fe243363601dfd6b7f"
ARG CHIPIFY_NAME="chipify"
RUN --mount=type=bind,source=images/chipify,target=/images/chipify \
    bash /images/chipify/scripts/install.sh
