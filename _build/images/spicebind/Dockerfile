# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile spicebind
#######################################################################
ARG TOOL_IMAGE_NGSPICE="registry.iic.jku.at:5000/iic-osic-tools:tool-ngspice-latest"
FROM ${TOOL_IMAGE_NGSPICE} AS spicebind
ARG SPICEBIND_REPO_URL="https://github.com/themperek/spicebind.git"
ARG SPICEBIND_REPO_COMMIT="a63974c81391c10c0700244c32c0b7733ae711b1"
ARG SPICEBIND_NAME="spicebind"
RUN --mount=type=bind,source=images/spicebind,target=/images/spicebind \
    bash /images/spicebind/scripts/install.sh
