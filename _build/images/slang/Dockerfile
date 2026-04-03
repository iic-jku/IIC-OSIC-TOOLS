#######################################################################
# Compile slang
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS slang
ARG SLANG_REPO_URL="https://github.com/MikePopoloski/slang.git"
ARG SLANG_REPO_COMMIT="eac03d0d6f3ff75231a078ea8b262104fa8e171a"
ARG SLANG_NAME="slang"
RUN --mount=type=bind,source=images/slang,target=/images/slang \
    bash /images/slang/scripts/install.sh
