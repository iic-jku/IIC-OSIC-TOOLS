#######################################################################
# Compile xyce & xyce-xdm
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS xyce
ARG XYCE_TRILINOS_REPO_URL="https://github.com/trilinos/Trilinos.git"
ARG XYCE_TRILINOS_REPO_COMMIT="trilinos-release-12-12-1"
ARG XYCE_TRILINOS_NAME="trilinos"
ARG XYCE_REPO_URL="https://github.com/Xyce/Xyce.git"
ARG XYCE_REPO_COMMIT="Release-7.9.0"
ARG XYCE_NAME="xyce"
USER 0:0
RUN --mount=type=bind,source=images/xyce,target=/images/xyce \
    bash /images/xyce/scripts/install.sh
