#######################################################################
# Compile spike (RISCV ISA simulator) and riscv-pk (RISCV proxy kernel and boot loader)
#######################################################################
ARG TOOL_IMAGE_RISCV_GNU_TOOLCHAIN="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"
FROM ${TOOL_IMAGE_RISCV_GNU_TOOLCHAIN} AS spike
ARG SPIKE_REPO_URL="https://github.com/riscv-software-src/riscv-isa-sim.git"
ARG SPIKE_REPO_COMMIT="34a42c3807534ed30de0839136cd19654587b5bb"
ARG SPIKE_NAME="spike"
ARG RISCV_PK_REPO_URL="https://github.com/riscv-software-src/riscv-pk.git"
ARG RISCV_PK_REPO_COMMIT="9c61d29846d8521d9487a57739330f9682d5b542"
RUN --mount=type=bind,source=images/spike,target=/images/spike \
    bash /images/spike/scripts/install.sh
