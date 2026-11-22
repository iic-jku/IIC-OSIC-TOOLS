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
ARG VACASK_REPO_COMMIT="2a432c7ce8f1ace6a709c6090dcd3efa7e9a9491"
ARG VACASK_NAME="vacask"
ARG EZ130_URL="https://iis-people.ee.ethz.ch/~iisdatasets/iip/ezlib/ihp130_8t/v1p1/ez130_8t_v1p1.zip"
ARG EZ130_MIRROR_URL="https://github.com/osic-tools/ez130-mirror/releases/download/v1p1/ez130_8t_v1p1.zip"
ARG EZ130_SHA256="4c072bae2089f13d258f7c8a9b2bdb4e74002791cc30be89f6d2beac3069d517"
ARG OPEN_PDKS_REPO_URL="https://github.com/RTimothyEdwards/open_pdks.git"
ARG OPEN_PDKS_REPO_COMMIT="1689ac3f2dc763876eaf967227c7dfe831b031ae"
ARG OPEN_PDKS_NAME="open_pdks"
COPY --from=openvaf ${TOOLS}/ ${TOOLS}/
COPY --from=xyce ${TOOLS}/ ${TOOLS}/
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ciel.sh
# Declared here so a bump of these rebuilds only the ICS55 and later layers
ARG ICS55_PDK_REPO_URL="https://github.com/openecos-projects/icsprout55-pdk.git"
ARG ICS55_PDK_REPO_COMMIT="bedd656c89ae7c6938c8538e8d8e7b3f018c55a9"
ARG ICS55_KLAYOUT_DRC_REPO_URL="https://github.com/Ayoubbelguellaoui/ics55_klayout_drc.git"
ARG ICS55_KLAYOUT_DRC_REPO_COMMIT="e084bab316af8626f4ce48512106804142f12d94"
ARG ICS55_OPENPDK_REPO_URL="https://github.com/ckdur/icsprout55-openpdk.git"
ARG ICS55_OPENPDK_REPO_COMMIT="efc7dfd61023f27cd3778f0dd7b19b63aa7bb17e"
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ics55.sh
# Set by docker-bake.hcl, declared here so a new value rebuilds only the IHP layers
ARG IHP_PDK_COMMIT=""
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ihp.sh
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ihp_cmos5l.sh
