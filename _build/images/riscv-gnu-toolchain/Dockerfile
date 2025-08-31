#######################################################################
# Compile riscv-gnu-toolchain
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS riscv-gnu-toolchain
ARG RISCV_GNU_TOOLCHAIN_REPO_URL="https://github.com/riscv-collab/riscv-gnu-toolchain.git"
ARG RISCV_GNU_TOOLCHAIN_REPO_COMMIT="2025.08.29"
ARG RISCV_GNU_TOOLCHAIN_NAME="riscv-gnu-toolchain"
USER 0:0
RUN --mount=type=bind,source=images/riscv-gnu-toolchain,target=/images/riscv-gnu-toolchain \
    bash /images/riscv-gnu-toolchain/scripts/install.sh
ENV RISCV=$TOOLS/$RISCV_GNU_TOOLCHAIN_NAME
