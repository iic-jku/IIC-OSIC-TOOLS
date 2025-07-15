#######################################################################
# Compile verilator
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS verilator
ARG VERILATOR_REPO_URL="https://github.com/verilator/verilator.git"
ARG VERILATOR_REPO_COMMIT="v5.038"
ARG VERILATOR_NAME="verilator"
USER 0:0
RUN --mount=type=bind,source=images/verilator,target=/images/verilator \
    bash /images/verilator/scripts/install.sh
