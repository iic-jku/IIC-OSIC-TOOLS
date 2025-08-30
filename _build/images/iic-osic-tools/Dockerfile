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
ARG TOOL_IMAGE_OPENROAD="registry.iic.jku.at:5000/iic-osic-tools:tool-openroad-latest"
ARG TOOL_IMAGE_OSIC_MULTITOOL="registry.iic.jku.at:5000/iic-osic-tools:tool-osic-multitool-latest"
ARG TOOL_IMAGE_OPENVAF="registry.iic.jku.at:5000/iic-osic-tools:tool-openvaf-latest"
ARG TOOL_IMAGE_PADRING="registry.iic.jku.at:5000/iic-osic-tools:tool-padring-latest"
ARG TOOL_IMAGE_PULP_TOOLS="registry.iic.jku.at:5000/iic-osic-tools:tool-pulp-tools-latest"
ARG TOOL_IMAGE_QFLOW="registry.iic.jku.at:5000/iic-osic-tools:tool-qflow-latest"
ARG TOOL_IMAGE_QUCS_S="registry.iic.jku.at:5000/iic-osic-tools:tool-qucs-s-latest"
ARG TOOL_IMAGE_RFTOOLKIT="registry.iic.jku.at:5000/iic-osic-tools:tool-rftoolkit-latest"
ARG TOOL_IMAGE_RISCV_GNU_TOOLCHAIN="registry.iic.jku.at:5000/iic-osic-tools:tool-riscv-gnu-toolchain-latest"
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
#ARG TOOL_IMAGE_XYCE_XDM="registry.iic.jku.at:5000/iic-osic-tools:tool-xyce-xdm-latest"
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
FROM ${TOOL_IMAGE_OPENROAD} AS openroad
FROM ${TOOL_IMAGE_OSIC_MULTITOOL} AS osic-multitool
FROM ${TOOL_IMAGE_OPENVAF} AS openvaf
FROM ${TOOL_IMAGE_PADRING} AS padring
FROM ${TOOL_IMAGE_PULP_TOOLS} AS pulp-tools
FROM ${TOOL_IMAGE_QFLOW} AS qflow
FROM ${TOOL_IMAGE_QUCS_S} AS qucs-s
FROM ${TOOL_IMAGE_RFTOOLKIT} AS rftoolkit
FROM ${TOOL_IMAGE_RISCV_GNU_TOOLCHAIN} AS riscv-gnu-toolchain
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
#FROM ${TOOL_IMAGE_XYCE_XDM} AS xyce-xdm
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
COPY --link --from=open_pdks                    ${PDK_ROOT}/            ${PDK_ROOT}/
COPY --link --from=covered                      ${TOOLS}/covered        ${TOOLS}/covered/
COPY --link --from=covered                      ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=cvc_rv                       ${TOOLS}/cvc_rv         ${TOOLS}/cvc_rv/
COPY --link --from=cvc_rv                       ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=gaw3-xschem                  ${TOOLS}/gaw3-xschem    ${TOOLS}/gaw3-xschem/
COPY --link --from=gaw3-xschem                  ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=gds3d                        ${TOOLS}/gds3d          ${TOOLS}/gds3d/
COPY --link --from=gds3d                        ${PDK_ROOT}/            ${PDK_ROOT}/
COPY --link --from=ghdl                         ${TOOLS}/ghdl           ${TOOLS}/ghdl/
COPY --link --from=ghdl                         ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=gtkwave                      ${TOOLS}/gtkwave        ${TOOLS}/gtkwave/
COPY --link --from=gtkwave                      ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=irsim                        ${TOOLS}/irsim          ${TOOLS}/irsim/
COPY --link --from=irsim                        ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=iverilog                     ${TOOLS}/iverilog       ${TOOLS}/iverilog/
COPY --link --from=iverilog                     ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=kactus2                      ${TOOLS}/kactus2        ${TOOLS}/kactus2/
COPY --link --from=klayout                      ${TOOLS}/klayout        ${TOOLS}/klayout/
COPY --link --from=libman                       ${TOOLS}/libman         ${TOOLS}/libman/
COPY --link --from=libman                       ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=magic                        ${TOOLS}/magic          ${TOOLS}/magic/
COPY --link --from=magic                        ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=netgen                       ${TOOLS}/netgen         ${TOOLS}/netgen/
COPY --link --from=netgen                       ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=nvc                          ${TOOLS}/nvc            ${TOOLS}/nvc/
COPY --link --from=nvc                          ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=ngspice                      ${TOOLS}/ngspice        ${TOOLS}/ngspice/
COPY --link --from=ngspice                      ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=ngspyce                      ${TOOLS}/ngspyce        ${TOOLS}/ngspyce/
COPY --link --from=ngspyce                      ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=openems                      ${TOOLS}/openems        ${TOOLS}/openems/
COPY --link --from=openems                      ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=openroad                     ${TOOLS}/openroad-latest      ${TOOLS}/openroad-latest/
COPY --link --from=openroad			      ${TOOLS}/openroad       ${TOOLS}/openroad/
COPY --link --from=openroad                     ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=osic-multitool               ${TOOLS}/osic-multitool ${TOOLS}/osic-multitool/
COPY --link --from=openvaf                      ${TOOLS}/openvaf        ${TOOLS}/openvaf/
COPY --link --from=openvaf                      ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=padring                      ${TOOLS}/padring        ${TOOLS}/padring/
COPY --link --from=padring                      ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=pulp-tools                   ${TOOLS}/pulp           ${TOOLS}/pulp/
COPY --link --from=pulp-tools                   ${TOOLS}/bin            ${TOOLS}/bin/
#FIXME COPY --link --from=pyopus                ${TOOLS}/               ${TOOLS}/
COPY --link --from=qflow                        ${TOOLS}/qflow          ${TOOLS}/qflow/
COPY --link --from=qflow                        ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=qucs-s                       ${TOOLS}/qucs-s         ${TOOLS}/qucs-s/
COPY --link --from=qucs-s                       ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=rftoolkit                    ${TOOLS}/rftoolkit      ${TOOLS}/rftoolkit/
COPY --link --from=rftoolkit                    ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=riscv-gnu-toolchain          ${TOOLS}/riscv-gnu-toolchain  ${TOOLS}/riscv-gnu-toolchain/
COPY --link --from=riscv-gnu-toolchain          ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=slang                        ${TOOLS}/slang          ${TOOLS}/slang/
COPY --link --from=slang                        ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=spike                        ${TOOLS}/spike          ${TOOLS}/spike/
COPY --link --from=spike                        ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=surelog                      ${TOOLS}/surelog        ${TOOLS}/surelog/
COPY --link --from=surelog                      ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=surfer                       ${TOOLS}/surfer         ${TOOLS}/surfer/
COPY --link --from=surfer                       ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=vacask                       ${TOOLS}/vacask         ${TOOLS}/vacask/
COPY --link --from=vacask                       ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=verilator                    ${TOOLS}/verilator      ${TOOLS}/verilator/
COPY --link --from=verilator                    ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=veryl                        ${TOOLS}/veryl          ${TOOLS}/veryl/
COPY --link --from=veryl                        ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=xcircuit                     ${TOOLS}/xcircuit       ${TOOLS}/xcircuit/
COPY --link --from=xcircuit                     ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=xschem                       ${TOOLS}/xschem         ${TOOLS}/xschem/
COPY --link --from=xschem                       ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=xyce                         ${TOOLS}/xyce           ${TOOLS}/xyce/
COPY --link --from=xyce                         ${TOOLS}/bin            ${TOOLS}/bin/
#COPY --link --from=xyce-xdm                     ${TOOLS}/xyce-xdm ${TOOLS}/bin              ${TOOLS}/
COPY --link --from=yosys                        ${TOOLS}/yosys          ${TOOLS}/yosys/
COPY --link --from=yosys                        ${TOOLS}/bin            ${TOOLS}/bin/
COPY --link --from=ghdl-yosys-plugin            ${TOOLS}_add/yosys/     ${TOOLS}/yosys/
COPY --link --from=slang-yosys-plugin           ${TOOLS}_add/yosys/     ${TOOLS}/yosys/

# Copy tool version file
COPY tool_metadata.yml /

# Copy EDA skeleton into image
COPY images/iic-osic-tools/skel_eda /

# Install EDA packages from Python, NPM, and GEM
RUN bash /headless/scripts/install_eda.sh

# Install examples
#RUN git clone --depth=1 https://github.com/iic-jku/SKY130_SAR-ADC1.git ${EXAMPLES}/SKY130_SAR-ADC1 && \
#    git clone --depth=1 https://github.com/iic-jku/SKY130_PLL1.git ${EXAMPLES}/SKY130_PLL1 && \
#    git clone --depth=1 https://github.com/mabrains/Analog_blocks.git ${EXAMPLES}/SKY130_ANALOG-BLOCKS
RUN git clone --depth=1 https://github.com/mole99/ota-5t.git ${EXAMPLES}/cace/ota-5t && \
    git clone --depth=1 https://github.com/iic-jku/analog-circuit-design ${EXAMPLES}/analog-course

# Install add-ons and additional scripts
RUN bash /headless/scripts/install_klayout.sh

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
