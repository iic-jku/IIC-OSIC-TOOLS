# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Create open_pdks
#######################################################################
ARG TOOL_IMAGE_OSIC_MULTITOOL="registry.iic.jku.at:5000/iic-osic-tools:tool-osic-multitool-latest"
ARG TOOL_IMAGE_OPENVAF="registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"
ARG TOOL_IMAGE_XYCE="registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-latest"

FROM ${TOOL_IMAGE_OPENVAF} AS openvaf
FROM ${TOOL_IMAGE_XYCE} AS xyce

FROM ${TOOL_IMAGE_OSIC_MULTITOOL} AS open_pdks
ARG VACASK_REPO_URL="https://codeberg.org/arpadbuermen/VACASK.git"
ARG VACASK_REPO_COMMIT="6434ed0aa6fefdb282af6d03f00be8f2455625f9"
ARG VACASK_NAME="vacask"
ARG OPEN_PDKS_REPO_URL="https://github.com/RTimothyEdwards/open_pdks.git"
ARG OPEN_PDKS_REPO_COMMIT="c95f23a75038d54d60ecc7ca060f53851f8f25e5"
ARG OPEN_PDKS_NAME="open_pdks"
COPY --from=openvaf ${TOOLS}/ ${TOOLS}/
COPY --from=xyce ${TOOLS}/ ${TOOLS}/
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ciel.sh
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ihp.sh
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ihp_cmos5l.sh
