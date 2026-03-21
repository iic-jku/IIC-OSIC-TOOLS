#######################################################################
# Install SVCK (SystemVerilog Checker/Linter) and Verible
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS svck
ARG SVCK_REPO_URL="https://github.com/AsFigo/svck.git"
ARG SVCK_REPO_COMMIT="997b49c20705ca3d99e8c0ebe57d6a7840513bb4"
ARG SVCK_NAME="svck"
ARG VERIBLE_VERSION="v0.0-4053-g89d4d98a"
RUN --mount=type=bind,source=images/svck,target=/images/svck \
    bash /images/svck/scripts/install.sh
