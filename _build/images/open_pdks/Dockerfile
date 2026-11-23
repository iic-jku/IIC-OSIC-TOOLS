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
ARG ICS55_PDK_REPO_COMMIT="10054695f86cf26a96ea8aba69f7ec414afde593"
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
ARG ASAP7_PDK_R1P7_REPO_URL="https://github.com/The-OpenROAD-Project/asap7_pdk_r1p7.git"
ARG ASAP7_PDK_R1P7_REPO_COMMIT="58d72c9d291e186a77468586ab0c43d8a21eda6a"
ARG ASAP7SC7P5T_28_REPO_URL="https://github.com/The-OpenROAD-Project/asap7sc7p5t_28.git"
ARG ASAP7SC7P5T_28_REPO_COMMIT="e5bd25da72cd297b8c0ec6f77600e0cbaa1124d0"
ARG OPENROAD_FLOW_SCRIPTS_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git"
ARG OPENROAD_FLOW_SCRIPTS_REPO_COMMIT="82ac25be57125cc724388ef89f01ce65f9ba3dcc"
ARG ASAP7_FOR_KLAYOUT_REPO_URL="https://github.com/laurentc2/ASAP7_for_KLayout.git"
ARG ASAP7_FOR_KLAYOUT_REPO_COMMIT="ef77f080381cab3993428492a3dcb41044c3f518"
ARG VA_MODELS_REPO_URL="https://github.com/dwarning/VA-Models.git"
ARG VA_MODELS_REPO_COMMIT="f04299a330591a591f309f4be1e208f83883ba2a"
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_asap7.sh
