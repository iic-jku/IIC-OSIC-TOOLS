#######################################################################
# Compile riscv-pk (RISCV proxy kernel and boot loader)
#######################################################################
ARG TOOL_IMAGE_RISCV_GNU_TOOLCHAIN="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"

FROM ${TOOL_IMAGE_RISCV_GNU_TOOLCHAIN} AS riscv-pk
ARG RISCV_PK_REPO_URL="https://github.com/riscv-software-src/riscv-pk.git"
ARG RISCV_PK_REPO_COMMIT="0239d921a2b06c931736e55462ba50233763ee33"
ARG RISCV_PK_NAME="riscv-pk"
USER 0:0
RUN --mount=type=bind,source=images/riscv-pk,target=/images/riscv-pk \
    bash /images/riscv-pk/scripts/install.sh
