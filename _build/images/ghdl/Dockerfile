#######################################################################
# Compile ghdl
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS ghdl
ARG GHDL_REPO_URL="https://github.com/ghdl/ghdl.git"
ARG GHDL_REPO_COMMIT="8c69dbd517970e7fc2e86ae3d6541c37d49bbcef"
ARG GHDL_NAME="ghdl"
RUN --mount=type=bind,source=images/ghdl,target=/images/ghdl \
    bash /images/ghdl/scripts/install.sh
