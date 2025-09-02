#######################################################################
# Compile veryl
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS veryl
ARG VERYL_NAME="veryl"
RUN --mount=type=bind,source=images/veryl,target=/images/veryl \
    bash /images/veryl/scripts/install.sh
