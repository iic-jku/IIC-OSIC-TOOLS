#######################################################################
# Compile osic-multitool
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS osic-multitool
ARG OSIC_MULTITOOL_REPO_URL="https://github.com/iic-jku/osic-multitool.git"
ARG OSIC_MULTITOOL_REPO_COMMIT="ab373a6b917635d1ae85b4d11397a1b708050f76"
ARG OSIC_MULTITOOL_NAME="osic-multitool"
RUN --mount=type=bind,source=images/osic-multitool,target=/images/osic-multitool \
    bash /images/osic-multitool/scripts/install.sh
