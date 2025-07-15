#######################################################################
# Setup individual build images
#######################################################################
ARG BASE_IMAGE=registry.iic.jku.at:5000/iic-osic-tools:base

ARG TOOL_IMAGE_OPEN_PDKS="registry.iic.jku.at:5000/iic-osic-tools:tool-open_pdks-latest"
ARG TOOL_IMAGE_COVERED="registry.iic.jku.at:5000/iic-osic-tools:tool-covered-latest"
ARG TOOL_IMAGE_CVC_RV="registry.iic.jku.at:5000/iic-osic-tools:tool-cvc_rv-latest"
ARG TOOL_IMAGE_GAW3_XSCHEM="registry.iic.jku.at:5000/iic-osic-tools:tool-gaw3-xschem-latest"
ARG TOOL_IMAGE_GDS3D="registry.iic.jku.at:5000/iic-osic-tools:tool-gds3d-latest"
ARG TOOL_IMAGE_GHDL="registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-latest"
ARG TOOL_IMAGE_GTKWAVE="registry.iic.jku.at:5000/iic-osic-tools:tool-gtkwave-latest"
ARG TOOL_IMAGE_IRSIM="registry.iic.jku.at:5000/iic-osic-tools:tool-irsim-latest"
ARG TOOL_IMAGE_IVERILOG="registry.iic.jku.at:5000/iic-osic-tools:tool-iverilog-latest"
ARG TOOL_IMAGE_KACTUS2="registry.iic.jku.at:5000/iic-osic-tools:tool-kactus2-latest"
ARG TOOL_IMAGE_KLAYOUT="registry.iic.jku.at:5000/iic-osic-tools:tool-klayout-latest"
ARG TOOL_IMAGE_LIBMAN="registry.iic.jku.at:5000/iic-osic-tools:tool-libman-latest"
ARG TOOL_IMAGE_MAGIC="registry.iic.jku.at:5000/iic-osic-tools:tool-magic-latest"
ARG TOOL_IMAGE_NETGEN="registry.iic.jku.at:5000/iic-osic-tools:tool-netgen-latest"
ARG TOOL_IMAGE_NVC="registry.iic.jku.at:5000/iic-osic-tools:tool-nvc-latest"
ARG TOOL_IMAGE_NGSPICE="registry.iic.jku.at:5000/iic-osic-tools:tool-ngspice-latest"
ARG TOOL_IMAGE_NGSPYCE="registry.iic.jku.at:5000/iic-osic-tools:tool-ngspyce-latest"
ARG TOOL_IMAGE_OPENEMS="registry.iic.jku.at:5000/iic-osic-tools:tool-openems-latest"
ARG TOOL_IMAGE_OPENROAD_APP="registry.iic.jku.at:5000/iic-osic-tools:tool-openroad_app-latest"
ARG TOOL_IMAGE_OSIC_MULTITOOL="registry.iic.jku.at:5000/iic-osic-tools:tool-osic-multitool-latest"
ARG TOOL_IMAGE_OPENVAF="registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"
ARG TOOL_IMAGE_PADRING="registry.iic.jku.at:5000/iic-osic-tools:tool-padring-latest"
ARG TOOL_IMAGE_PULP_TOOLS="registry.iic.jku.at:5000/iic-osic-tools:tool-pulp-tools-latest"
ARG TOOL_IMAGE_QFLOW="registry.iic.jku.at:5000/iic-osic-tools:tool-qflow-latest"
ARG TOOL_IMAGE_QUCS_S="registry.iic.jku.at:5000/iic-osic-tools:tool-qucs-s-latest"
ARG TOOL_IMAGE_RFTOOLKIT="registry.iic.jku.at:5000/iic-osic-tools:tool-rftoolkit-latest"
ARG TOOL_IMAGE_RISCV_GNU_TOOLCHAIN="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"
ARG TOOL_IMAGE_RISCV_PK="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-pk-latest"
ARG TOOL_IMAGE_SLANG="registry.iic.jku.at:5000/iic-osic-tools:tool-slang-latest"
ARG TOOL_IMAGE_SPIKE="registry.iic.jku.at:5000/iic-osic-tools:tool-spike-latest"
ARG TOOL_IMAGE_SURELOG="registry.iic.jku.at:5000/iic-osic-tools:tool-surelog-latest"
ARG TOOL_IMAGE_SURFER="registry.iic.jku.at:5000/iic-osic-tools:tool-surfer-latest"
ARG TOOL_IMAGE_VACASK="registry.iic.jku.at:5000/iic-osic-tools:tool-vacask-latest"
ARG TOOL_IMAGE_VERILATOR="registry.iic.jku.at:5000/iic-osic-tools:tool-verilator-latest"
ARG TOOL_IMAGE_VERYL="registry.iic.jku.at:5000/iic-osic-tools:tool-veryl-latest"
ARG TOOL_IMAGE_XCIRCUIT="registry.iic.jku.at:5000/iic-osic-tools:tool-xcircuit-latest"
ARG TOOL_IMAGE_XSCHEM="registry.iic.jku.at:5000/iic-osic-tools:tool-xschem-latest"
ARG TOOL_IMAGE_XYCE="registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-latest"
ARG TOOL_IMAGE_XYCE_XDM="registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-xdm-latest"
ARG TOOL_IMAGE_YOSYS="registry.iic.jku.at:5000/iic-osic-tools:tool-yosys-latest"
ARG TOOL_IMAGE_GHDL_YOSYS_PLUGIN="registry.iic.jku.at:5000/iic-osic-tools:tool-ghdl-yosys-plugin-latest"
ARG TOOL_IMAGE_SLANG_YOSYS_PLUGIN="registry.iic.jku.at:5000/iic-osic-tools:tool-slang-yosys-plugin-latest"

FROM ${TOOL_IMAGE_OPEN_PDKS} AS open_pdks
FROM ${TOOL_IMAGE_COVERED} AS covered
FROM ${TOOL_IMAGE_CVC_RV} AS cvc_rv
FROM ${TOOL_IMAGE_GAW3_XSCHEM} AS gaw3-xschem
FROM ${TOOL_IMAGE_GDS3D} AS gds3d
FROM ${TOOL_IMAGE_GHDL} AS ghdl
FROM ${TOOL_IMAGE_GTKWAVE} AS gtkwave
FROM ${TOOL_IMAGE_IRSIM} AS irsim
FROM ${TOOL_IMAGE_IVERILOG} AS iverilog
FROM ${TOOL_IMAGE_KACTUS2} AS kactus2
FROM ${TOOL_IMAGE_KLAYOUT} AS klayout
FROM ${TOOL_IMAGE_LIBMAN} AS libman
FROM ${TOOL_IMAGE_MAGIC} AS magic
FROM ${TOOL_IMAGE_NETGEN} AS netgen
FROM ${TOOL_IMAGE_NVC} AS nvc
FROM ${TOOL_IMAGE_NGSPICE} AS ngspice
FROM ${TOOL_IMAGE_NGSPYCE} AS ngspyce
FROM ${TOOL_IMAGE_OPENEMS} AS openems
FROM ${TOOL_IMAGE_OPENROAD_APP} AS openroad_app
FROM ${TOOL_IMAGE_OSIC_MULTITOOL} AS osic-multitool
FROM ${TOOL_IMAGE_OPENVAF} AS openvaf
FROM ${TOOL_IMAGE_PADRING} AS padring
FROM ${TOOL_IMAGE_PULP_TOOLS} AS pulp-tools
FROM ${TOOL_IMAGE_QFLOW} AS qflow
FROM ${TOOL_IMAGE_QUCS_S} AS qucs-s
FROM ${TOOL_IMAGE_RFTOOLKIT} AS rftoolkit
FROM ${TOOL_IMAGE_RISCV_GNU_TOOLCHAIN} AS riscv-gnu-toolchain
FROM ${TOOL_IMAGE_RISCV_PK} AS riscv-pk
FROM ${TOOL_IMAGE_SLANG} AS slang
FROM ${TOOL_IMAGE_SPIKE} AS spike
FROM ${TOOL_IMAGE_SURELOG} AS surelog
FROM ${TOOL_IMAGE_SURFER} AS surfer
FROM ${TOOL_IMAGE_VACASK} AS vacask
FROM ${TOOL_IMAGE_VERILATOR} AS verilator
FROM ${TOOL_IMAGE_VERYL} AS veryl
FROM ${TOOL_IMAGE_XCIRCUIT} AS xcircuit
FROM ${TOOL_IMAGE_XSCHEM} AS xschem
FROM ${TOOL_IMAGE_XYCE} AS xyce
FROM ${TOOL_IMAGE_XYCE_XDM} AS xyce-xdm
FROM ${TOOL_IMAGE_YOSYS} AS yosys
FROM ${TOOL_IMAGE_GHDL_YOSYS_PLUGIN} AS ghdl-yosys-plugin
FROM ${TOOL_IMAGE_SLANG_YOSYS_PLUGIN} AS slang-yosys-plugin

#######################################################################
# Final output container
#######################################################################
FROM ${BASE_IMAGE} AS iic-osic-tools
ARG CONTAINER_TAG=unknown
ENV IIC_OSIC_TOOLS_VERSION=${CONTAINER_TAG}

# Copy all layers into the final container
COPY --from=open_pdks                    ${PDK_ROOT}/           ${PDK_ROOT}/
COPY --from=covered                      ${TOOLS}/              ${TOOLS}/
COPY --from=cvc_rv                       ${TOOLS}/              ${TOOLS}/
COPY --from=gaw3-xschem                  ${TOOLS}/              ${TOOLS}/
COPY --from=gds3d                        ${TOOLS}/              ${TOOLS}/
COPY --from=gds3d                        ${PDK_ROOT}/           ${PDK_ROOT}/
COPY --from=ghdl                         ${TOOLS}/              ${TOOLS}/
COPY --from=gtkwave                      ${TOOLS}/              ${TOOLS}/
COPY --from=irsim                        ${TOOLS}/              ${TOOLS}/
COPY --from=iverilog                     ${TOOLS}/              ${TOOLS}/
COPY --from=kactus2                       ${TOOLS}/              ${TOOLS}/
COPY --from=klayout                      ${TOOLS}/              ${TOOLS}/
COPY --from=libman                       ${TOOLS}/              ${TOOLS}/
COPY --from=magic                        ${TOOLS}/              ${TOOLS}/
COPY --from=netgen                       ${TOOLS}/              ${TOOLS}/
COPY --from=nvc                          ${TOOLS}/              ${TOOLS}/
COPY --from=ngspice                      ${TOOLS}/              ${TOOLS}/
COPY --from=ngspyce                      ${TOOLS}/              ${TOOLS}/
COPY --from=openems                      ${TOOLS}/              ${TOOLS}/
COPY --from=openroad_app                 ${TOOLS}/              ${TOOLS}/
COPY --from=osic-multitool               ${TOOLS}/              ${TOOLS}/
COPY --from=openvaf                      ${TOOLS}/              ${TOOLS}/
COPY --from=padring                      ${TOOLS}/              ${TOOLS}/
COPY --from=pulp-tools                   ${TOOLS}/              ${TOOLS}/
#FIXME COPY --from=pyopus                ${TOOLS}/              ${TOOLS}/
COPY --from=qflow                        ${TOOLS}/              ${TOOLS}/
COPY --from=qucs-s                       ${TOOLS}/              ${TOOLS}/
COPY --from=rftoolkit                    ${TOOLS}/              ${TOOLS}/
COPY --from=riscv-gnu-toolchain          ${TOOLS}/              ${TOOLS}/
COPY --from=riscv-pk                     ${TOOLS}/              ${TOOLS}/
COPY --from=slang                        ${TOOLS}/              ${TOOLS}/
COPY --from=spike                        ${TOOLS}/              ${TOOLS}/
COPY --from=surelog                      ${TOOLS}/              ${TOOLS}/
COPY --from=surfer                       ${TOOLS}/              ${TOOLS}/
COPY --from=vacask                       ${TOOLS}/              ${TOOLS}/
COPY --from=verilator                    ${TOOLS}/              ${TOOLS}/
COPY --from=veryl                        ${TOOLS}/              ${TOOLS}/
COPY --from=xcircuit                     ${TOOLS}/              ${TOOLS}/
COPY --from=xschem                       ${TOOLS}/              ${TOOLS}/
COPY --from=xyce                         ${TOOLS}/              ${TOOLS}/
COPY --from=xyce-xdm                     ${TOOLS}/              ${TOOLS}/
COPY --from=yosys                        ${TOOLS}/              ${TOOLS}/
COPY --from=ghdl-yosys-plugin            ${TOOLS}_add/          ${TOOLS}/
COPY --from=slang-yosys-plugin           ${TOOLS}_add/          ${TOOLS}/

# Copy tool version file
COPY tool_metadata.yml /

# Metadata labels
LABEL org.opencontainers.image.authors="Harald Pretl <harald.pretl@jku.at>; Georg Zachl <georg.zachl@jku.at>" \
      org.opencontainers.image.url="https://github.com/iic-jku/iic-osic-tools" \
      org.opencontainers.image.documentation="https://github.com/iic-jku/IIC-OSIC-TOOLS/blob/main/README.md" \
      org.opencontainers.image.source="https://github.com/iic-jku/IIC-OSIC-TOOLS" \
      org.opencontainers.image.version="${CONTAINER_TAG}" \
      org.opencontainers.image.vendor="Department for Integrated Circuits" \
      org.opencontainers.image.licenses=" Apache-2.0" \
      org.opencontainers.image.ref.name="${CONTAINER_TAG}" \
      org.opencontainers.image.title="IIC Open Source Integrated Circuit Tools" \
      org.opencontainers.image.description="IIC-OSIC-TOOLS (Integrated Infrastructure for Collaborative Open Source IC Tools) is an all-in-one Docker container for open-source-based integrated circuit designs for analog and digital circuit flows."
