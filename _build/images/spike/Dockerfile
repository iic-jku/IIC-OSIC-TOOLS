# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile spike (RISCV ISA simulator) and riscv-pk (RISCV proxy kernel and boot loader)
#######################################################################
ARG TOOL_IMAGE_RISCV_GNU_TOOLCHAIN="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"
FROM ${TOOL_IMAGE_RISCV_GNU_TOOLCHAIN} AS spike
ARG SPIKE_REPO_URL="https://github.com/riscv-software-src/riscv-isa-sim.git"
ARG SPIKE_REPO_COMMIT="c567a199a7dbd9c0f5689e0567415c76d9a21ade"
ARG SPIKE_NAME="spike"
ARG RISCV_PK_REPO_URL="https://github.com/riscv-software-src/riscv-pk.git"
ARG RISCV_PK_REPO_COMMIT="9c61d29846d8521d9487a57739330f9682d5b542"
RUN --mount=type=bind,source=images/spike,target=/images/spike \
    bash /images/spike/scripts/install.sh
