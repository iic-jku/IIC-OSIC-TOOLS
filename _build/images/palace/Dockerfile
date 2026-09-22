# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile palace
#######################################################################
ARG TOOL_IMAGE_PALACE=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${TOOL_IMAGE_PALACE} AS palace
ARG PALACE_REPO_URL="https://github.com/awslabs/palace"
ARG PALACE_REPO_COMMIT="0dc74cdf8c36c58b69b21c4a06e816048ec0b83f"
ARG PALACE_NAME="palace"
RUN --mount=type=bind,source=images/palace,target=/images/palace \
    bash /images/palace/scripts/install.sh
