#######################################################################
# Compile ngspyce
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS ngspyce
ARG NGSPYCE_REPO_URL="https://github.com/ignamv/ngspyce.git"
ARG NGSPYCE_REPO_COMMIT="154a2724080e3bf15827549bba9f315cd11984fe"
ARG NGSPYCE_NAME="ngspyce"
RUN --mount=type=bind,source=images/ngspyce,target=/images/ngspyce \
    bash /images/ngspyce/scripts/install.sh
