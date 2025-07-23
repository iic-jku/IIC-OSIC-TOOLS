#######################################################################
# Compile spike (RISCV ISA simulator)
#######################################################################
ARG TOOL_IMAGE_RISCV_GNU_TOOLCHAIN="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"
FROM ${TOOL_IMAGE_RISCV_GNU_TOOLCHAIN} AS spike
ARG SPIKE_REPO_URL="https://github.com/riscv-software-src/riscv-isa-sim.git"
ARG SPIKE_REPO_COMMIT="3e58f5ef626fa76dd6675f1f78c6cd8470e18727"
ARG SPIKE_NAME="spike"
USER 0:0
RUN --mount=type=bind,source=images/spike,target=/images/spike \
    bash /images/spike/scripts/install.sh
