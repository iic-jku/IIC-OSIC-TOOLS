# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile cvc_rv
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS cvc_rv
ARG CVC_RV_REPO_URL="https://github.com/d-m-bailey/cvc.git"
ARG CVC_RV_REPO_COMMIT="23c3867bb9c227ec395e2812b318379ffb9a0df9"
ARG CVC_RV_NAME="cvc_rv"
RUN --mount=type=bind,source=images/cvc_rv,target=/images/cvc_rv \
    bash /images/cvc_rv/scripts/install.sh
