#######################################################################
# Compile padring
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS padring
ARG PADRING_REPO_URL="https://github.com/iic-jku/padring.git"
ARG PADRING_REPO_COMMIT="17fba2638142baa4dc6e2a0b18cb1cd542017e16"
ARG PADRING_NAME="padring"
RUN --mount=type=bind,source=images/padring,target=/images/padring \
    bash /images/padring/scripts/install.sh
