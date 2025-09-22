#######################################################################
# Compile FPGA tools (icestorm, nextpnr) prepared for iCE-40
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS fpga-tools
ARG FPGA_NAME="fpga"
RUN --mount=type=bind,source=images/fpga-tools,target=/images/fpga-tools \
    bash /images/fpga-tools/scripts/install.sh
