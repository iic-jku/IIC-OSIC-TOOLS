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
ARG VACASK_REPO_COMMIT="8d9993b610b43d8b08474eef9f1501c165842b98"
ARG VACASK_NAME="vacask"
ARG OPEN_PDKS_REPO_URL="https://github.com/RTimothyEdwards/open_pdks.git"
ARG OPEN_PDKS_REPO_COMMIT="7b70722e33c03fcb5dabcf4d479fb0822d9251c9"
ARG OPEN_PDKS_NAME="open_pdks"
COPY --from=openvaf ${TOOLS}/ ${TOOLS}/
COPY --from=xyce ${TOOLS}/ ${TOOLS}/
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ciel.sh
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ihp.sh
