# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile vacask
#######################################################################
ARG TOOL_IMAGE_OPENVAF="registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"
FROM ${TOOL_IMAGE_OPENVAF} AS vacask
ARG VACASK_REPO_URL="https://codeberg.org/arpadbuermen/VACASK.git"
ARG VACASK_REPO_COMMIT="d41e5e3d6ffdd97dd3342b391bc1c7a335d0e581"
ARG VACASK_NAME="vacask"
RUN --mount=type=bind,source=images/vacask,target=/images/vacask \
    bash /images/vacask/scripts/install.sh
