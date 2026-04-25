# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile Slang Yosys plugin
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
ARG TOOL_IMAGE_YOSYS="registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"

FROM ${TOOL_IMAGE_YOSYS} AS yosys
FROM ${BASE_IMAGE_BUILD} AS slang-yosys-plugin

ARG SLANG_YOSYS_PLUGIN_REPO_URL="https://github.com/povik/yosys-slang.git"
ARG SLANG_YOSYS_PLUGIN_REPO_COMMIT="3a7f19d9783de95f58940d9e983d068959a07ada"
ARG SLANG_YOSYS_PLUGIN_NAME="slang-yosys-plugin"

COPY --from=yosys	${TOOLS}    ${TOOLS}

RUN --mount=type=bind,source=images/slang-yosys-plugin,target=/images/slang-yosys-plugin \
    bash /images/slang-yosys-plugin/scripts/install.sh
