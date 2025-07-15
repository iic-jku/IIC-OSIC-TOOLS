#######################################################################
# Compile slang
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS slang
ARG SLANG_REPO_URL="https://github.com/MikePopoloski/slang.git"
ARG SLANG_REPO_COMMIT="66fa94a4862e6dd49c32036b57eaa1d3a76b6c29"
ARG SLANG_NAME="slang"
USER 0:0
RUN --mount=type=bind,source=images/slang,target=/images/slang \
    bash /images/slang/scripts/install.sh
