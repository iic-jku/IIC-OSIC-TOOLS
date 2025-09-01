#######################################################################
# Compile surelog
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS surelog
ARG SURELOG_REPO_URL="https://github.com/chipsalliance/Surelog.git"
ARG SURELOG_REPO_COMMIT="v1.86"
ARG SURELOG_NAME="surelog"
RUN --mount=type=bind,source=images/surelog,target=/images/surelog \
    bash /images/surelog/scripts/install.sh
