#######################################################################
# Add dev packages to base image 
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS base-dev
RUN --mount=type=bind,source=images/base-dev,target=/images/base-dev \
    bash /images/base-dev/scripts/install.sh
