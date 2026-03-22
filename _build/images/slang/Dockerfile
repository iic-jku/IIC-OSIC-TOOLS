#######################################################################
# Compile slang
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS slang
ARG SLANG_REPO_URL="https://github.com/MikePopoloski/slang.git"
ARG SLANG_REPO_COMMIT="cf4f46e042bfef4fc1d9dd4df93862d63424cb69"
ARG SLANG_NAME="slang"
RUN --mount=type=bind,source=images/slang,target=/images/slang \
    bash /images/slang/scripts/install.sh
