#######################################################################
# Compile spike (RISCV ISA simulator)
#######################################################################
ARG TOOL_IMAGE_RISCV_GNU_TOOLCHAIN="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"
FROM ${TOOL_IMAGE_RISCV_GNU_TOOLCHAIN} AS spike

ARG SPIKE_REPO_URL="https://github.com/riscv-software-src/riscv-isa-sim.git"
ARG SPIKE_REPO_COMMIT="965547260a803a77d10f8f628bda61bea4b1464f"
ARG SPIKE_NAME="spike"
USER 0:0
RUN --mount=type=bind,source=images/spike,target=/images/spike \
    bash /images/spike/scripts/install.sh
