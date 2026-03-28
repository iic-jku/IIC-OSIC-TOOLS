#######################################################################
# Install uv
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS uv
ARG UV_REPO_URL="https://github.com/astral-sh/uv"
ARG UV_NAME="uv"
ARG UV_VERSION="0.6.6"
RUN --mount=type=bind,source=images/uv,target=/images/uv \
    bash /images/uv/scripts/install.sh
