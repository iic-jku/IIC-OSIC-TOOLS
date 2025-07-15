#######################################################################
# Compile ghdl
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS ghdl
ARG GHDL_REPO_URL="https://github.com/ghdl/ghdl.git"
ARG GHDL_REPO_COMMIT="870738a4d2326c053e96007fe17a390427926efd"
ARG GHDL_NAME="ghdl"
USER 0:0
RUN --mount=type=bind,source=images/ghdl,target=/images/ghdl \
    bash /images/ghdl/scripts/install.sh
