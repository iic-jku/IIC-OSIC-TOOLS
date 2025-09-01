#######################################################################
# Compile spike (RISCV ISA simulator) and riscv-pk (RISCV proxy kernel and boot loader)
#######################################################################
ARG TOOL_IMAGE_RISCV_GNU_TOOLCHAIN="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"
FROM ${TOOL_IMAGE_RISCV_GNU_TOOLCHAIN} AS spike
ARG SPIKE_REPO_URL="https://github.com/riscv-software-src/riscv-isa-sim.git"
ARG SPIKE_REPO_COMMIT="9c190a07c6838f6392bafa4ad83acea462c7f759"
ARG SPIKE_NAME="spike"
ARG RISCV_PK_REPO_URL="https://github.com/riscv-software-src/riscv-pk.git"
ARG RISCV_PK_REPO_COMMIT="b4abf92e9954aaed291d0282c580f94254f9b11c"
RUN --mount=type=bind,source=images/spike,target=/images/spike \
    bash /images/spike/scripts/install.sh
