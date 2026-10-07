# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile openvaf-reloaded
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS openvaf
ARG OPENVAF_REPO_URL="https://github.com/arpadbuermen/OpenVAF.git"
# Pinned to branch mb-experimental (OSDI 0.5): master emits OSDI 0.4, which
# drops absdelay(), so every delay in VACASK is silently zero (see
# https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/375). Return to master once
# it emits OSDI 0.5, and drop the branch key in tool_metadata.yml with it.
ARG OPENVAF_REPO_COMMIT="fbd1d4a1a9adba7e8c55cc8d30c7e08cd6f29cb7"
ARG OPENVAF_NAME="openvaf"
ENV OPENVAF_NAME=${OPENVAF_NAME}
RUN --mount=type=bind,source=images/openvaf,target=/images/openvaf \
    bash /images/openvaf/scripts/install.sh
