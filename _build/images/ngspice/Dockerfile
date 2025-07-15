#######################################################################
# Compile ngspice
#######################################################################
ARG TOOL_IMAGE_OPEN_PDKS="registry.iic.jku.at:5000/iic-osic-tools:tool-open_pdks-latest"
FROM ${TOOL_IMAGE_OPEN_PDKS} AS ngspice
ARG NGSPICE_REPO_URL="https://github.com/danchitnis/ngspice-sf-mirror.git"
ARG NGSPICE_REPO_COMMIT="ngspice-44.2"
ARG NGSPICE_NAME="ngspice"
USER 0:0
RUN --mount=type=bind,source=images/ngspice,target=/images/ngspice \
    bash /images/ngspice/scripts/install.sh
