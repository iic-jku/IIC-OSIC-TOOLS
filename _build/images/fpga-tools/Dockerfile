#######################################################################
# Compile FPGA tools (icestorm, nextpnr) prepared for iCE-40
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS fpga-tools
ARG FPGA_NAME="fpga"
ARG ICESTORM_REPO_URL="https://github.com/YosysHQ/icestorm.git"
ARG ICESTORM_REPO_COMMIT="f31c39cc2eadd0ab7f29f34becba1348ae9f8721"
ARG NEXTPNR_REPO_URL="https://github.com/YosysHQ/nextpnr.git"
ARG NEXTPNR_REPO_COMMIT="e9b7da5a0f493109f9b5a04bda039c9d080794fb"
RUN --mount=type=bind,source=images/fpga-tools,target=/images/fpga-tools \
    bash /images/fpga-tools/scripts/install.sh
