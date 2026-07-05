# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile kepler-formal
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
FROM ${BASE_IMAGE_BUILD} AS kepler-formal
ARG KEPLER_FORMAL_REPO_URL="https://github.com/keplertech/kepler-formal.git"
ARG KEPLER_FORMAL_REPO_COMMIT="df2fff283392e98b7f0710914529001f0893c844"
ARG KEPLER_FORMAL_NAME="kepler-formal"
RUN --mount=type=bind,source=images/kepler-formal,target=/images/kepler-formal \
    bash /images/kepler-formal/scripts/install.sh
