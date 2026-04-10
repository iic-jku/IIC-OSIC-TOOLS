# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile ngspice
#######################################################################
ARG TOOL_IMAGE_OPEN_PDKS="registry.iic.jku.at:5000/iic-osic-tools:tool-open_pdks-latest"
FROM ${TOOL_IMAGE_OPEN_PDKS} AS ngspice
ARG NGSPICE_REPO_URL="https://github.com/danchitnis/ngspice-sf-mirror.git"
ARG NGSPICE_REPO_COMMIT="ngspice-46"
ARG NGSPICE_NAME="ngspice"
RUN --mount=type=bind,source=images/ngspice,target=/images/ngspice \
    bash /images/ngspice/scripts/install.sh
