#######################################################################
# Compile ghdl
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS ghdl
ARG GHDL_REPO_URL="https://github.com/ghdl/ghdl.git"
ARG GHDL_REPO_COMMIT="e759a12f6d4ac26268e8c5b54e8fa59bbbd34192"
ARG GHDL_NAME="ghdl"
RUN --mount=type=bind,source=images/ghdl,target=/images/ghdl \
    bash /images/ghdl/scripts/install.sh
