#######################################################################
# Setup individual build images
#######################################################################
ARG BASE_IMAGE=iic-osic-tools:base
ARG BASE_IMAGE_BUILD=iic-osic-tools:base-dev
FROM ${BASE_IMAGE} AS base-dev
ARG CONTAINER_TAG=unknown
ENV IIC_OSIC_TOOLS_VERSION=${CONTAINER_TAG}

#######################################################################
# Compile magic
#######################################################################
FROM base-dev AS magic
ARG MAGIC_REPO_URL="https://github.com/rtimothyedwards/magic.git"
ARG MAGIC_REPO_COMMIT="8.3.530"
ARG MAGIC_NAME="magic"
COPY images/magic/scripts/install.sh install.sh
RUN --mount=type=bind,source=images/magic,target=/images/magic \
    bash /images/magic/scripts/install.sh

#######################################################################
# Compile openvaf-reloaded
#######################################################################
FROM base-dev AS openvaf
ARG OPENVAF_REPO_URL="https://github.com/arpadbuermen/OpenVAF.git"
ARG OPENVAF_REPO_COMMIT="643fcead0564aa915761257c08bd7f92c7634639"
ARG OPENVAF_NAME="openvaf"
ENV OPENVAF_NAME=${OPENVAF_NAME}
RUN --mount=type=bind,source=images/openvaf,target=/images/openvaf \
    bash /images/openvaf/scripts/install.sh

#######################################################################
# Compile osic-multitool
#######################################################################
FROM base-dev AS osic-multitool
ARG OSIC_MULTITOOL_REPO_URL="https://github.com/iic-jku/osic-multitool.git"
ARG OSIC_MULTITOOL_REPO_COMMIT="ab373a6b917635d1ae85b4d11397a1b708050f76"
ARG OSIC_MULTITOOL_NAME="osic-multitool"
RUN --mount=type=bind,source=images/osic-multitool,target=/images/osic-multitool \
    bash /images/osic-multitool/scripts/install.sh

#######################################################################
# Compile xyce & xyce-xdm
#######################################################################
FROM base-dev AS xyce
ARG XYCE_TRILINOS_REPO_URL="https://github.com/trilinos/Trilinos.git"
ARG XYCE_TRILINOS_REPO_COMMIT="trilinos-release-12-12-1"
ARG XYCE_TRILINOS_NAME="trilinos"
ARG XYCE_REPO_URL="https://github.com/Xyce/Xyce.git"
ARG XYCE_REPO_COMMIT="Release-7.9.0"
ARG XYCE_NAME="xyce"
RUN --mount=type=bind,source=images/xyce,target=/images/xyce \
    bash /images/xyce/scripts/install.sh

FROM xyce AS xyce-xdm
ARG XYCE_XDM_REPO_URL="https://github.com/Xyce/XDM.git"
ARG XYCE_XDM_REPO_COMMIT="Release-2.7.0"
ARG XYCE_XDM_NAME="xyce-xdm"
#FIXME XDM has build fails in 24.04 LTS, not sure why; remove it for the
#      time being
#RUN --mount=type=bind,source=images/xyce-xdm,target=/images/xyce-xdm \
#    bash /images/xyce-xdm/scripts/install.sh

#######################################################################
# Create open_pdks
#######################################################################
FROM osic-multitool AS open_pdks
ARG OPEN_PDKS_REPO_URL="https://github.com/RTimothyEdwards/open_pdks.git"
ARG OPEN_PDKS_REPO_COMMIT="0fe599b2afb6708d281543108caf8310912f54af"
ARG OPEN_PDKS_NAME="open_pdks"
COPY --from=openvaf ${TOOLS}/ ${TOOLS}/
COPY --from=xyce ${TOOLS}/ ${TOOLS}/
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ciel.sh
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ihp.sh

#######################################################################
# Compile covered 
#######################################################################
FROM base-dev AS covered
ARG COVERED_REPO_URL="https://github.com/hpretl/verilog-covered.git"
ARG COVERED_REPO_COMMIT="19d30fc942642b14dc24e95331cd4777c8dcbad9"
ARG COVERED_NAME="covered"
RUN --mount=type=bind,source=images/covered,target=/images/covered \
    bash /images/covered/scripts/install.sh

#######################################################################
# Compile cvc_rv
#######################################################################
FROM base-dev AS cvc_rv
ARG CVC_RV_REPO_URL="https://github.com/d-m-bailey/cvc.git"
ARG CVC_RV_REPO_COMMIT="d359e88cdd2eda722360b177b57942106f0a378b"
ARG CVC_RV_NAME="cvc_rv"
RUN --mount=type=bind,source=images/cvc_rv,target=/images/cvc_rv \
    bash /images/cvc_rv/scripts/install.sh

#######################################################################
# Compile gaw3-xschem
#######################################################################
FROM base-dev AS gaw3-xschem
ARG GAW3_XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem-gaw.git"
ARG GAW3_XSCHEM_REPO_COMMIT="6b8fa4ab007e88b3129381e0479737ae014a8b51"
ARG GAW3_XSCHEM_NAME="gaw3-xschem"
RUN --mount=type=bind,source=images/gaw3-xschem,target=/images/gaw3-xschem \
    bash /images/gaw3-xschem/scripts/install.sh

#######################################################################
# Compile GDS3D
#######################################################################
FROM open_pdks AS gds3d
ARG GDS3D_REPO_URL="https://github.com/trilomix/GDS3D.git"
ARG GDS3D_REPO_COMMIT="dc6d965225c9f5ed2a6faefb7ea30665429060fe"
ARG GDS3D_NAME="gds3d"
RUN --mount=type=bind,source=images/gds3d,target=/images/gds3d \
    bash /images/gds3d/scripts/install.sh

#######################################################################
# Compile ghdl
#######################################################################
FROM base-dev AS ghdl
ARG GHDL_REPO_URL="https://github.com/ghdl/ghdl.git"
ARG GHDL_REPO_COMMIT="870738a4d2326c053e96007fe17a390427926efd"
ARG GHDL_NAME="ghdl"
RUN --mount=type=bind,source=images/ghdl,target=/images/ghdl \
    bash /images/ghdl/scripts/install.sh

#######################################################################
# Compile gtkwave
#######################################################################
FROM base-dev AS gtkwave
ARG GTKWAVE_REPO_URL="https://github.com/gtkwave/gtkwave.git"
ARG GTKWAVE_REPO_COMMIT="bb978d9d667d569b9153ffa34007e300302907dc"
ARG GTKWAVE_NAME="gtkwave"
RUN --mount=type=bind,source=images/gtkwave,target=/images/gtkwave \
    bash /images/gtkwave/scripts/install.sh

#######################################################################
# Compile irsim
#######################################################################
FROM base-dev AS irsim
ARG IRSIM_REPO_URL="https://github.com/rtimothyedwards/irsim.git"
ARG IRSIM_REPO_COMMIT="34b1e7bbb1014346a5bbe9171bd25840ee020578"
ARG IRSIM_NAME="irsim"
RUN --mount=type=bind,source=images/irsim,target=/images/irsim \
    bash /images/irsim/scripts/install.sh

#######################################################################
# Compile iverilog
#######################################################################
FROM base-dev AS iverilog
ARG IVERILOG_REPO_URL="https://github.com/steveicarus/iverilog.git"
ARG IVERILOG_REPO_COMMIT="f82c6c7b3ada873015348f728aa3087cdb6661a6"
ARG IVERILOG_NAME="iverilog"
RUN --mount=type=bind,source=images/iverilog,target=/images/iverilog \
    bash /images/iverilog/scripts/install.sh

#######################################################################
# Compile kactus2
#######################################################################
FROM base-dev AS kactus
ARG KACTUS_REPO_URL="https://github.com/kactus2/kactus2dev.git"
ARG KACTUS_REPO_COMMIT="v3.13.5"
ARG KACTUS_NAME="kactus2"
RUN --mount=type=bind,source=images/kactus2,target=/images/kactus2 \
    bash /images/kactus2/scripts/install.sh

#######################################################################
# Compile klayout
#######################################################################
FROM base-dev AS klayout
ARG KLAYOUT_REPO_URL="https://github.com/KLayout/klayout.git"
ARG KLAYOUT_REPO_COMMIT="v0.30.2"
ARG KLAYOUT_NAME="klayout"
RUN --mount=type=bind,source=images/klayout,target=/images/klayout \
    bash /images/klayout/scripts/install.sh

#######################################################################
# Compile libman
#######################################################################
FROM base-dev AS libman
ARG LIBMAN_REPO_URL="https://github.com/IHP-GmbH/LibMan.git"
ARG LIBMAN_REPO_COMMIT="09ff4bac10bd6f47c432579c25f9b39d4f44bb47"
ARG LIBMAN_NAME="libman"
RUN --mount=type=bind,source=images/libman,target=/images/libman \
    bash /images/libman/scripts/install.sh

#######################################################################
# Compile netgen
#######################################################################
FROM base-dev AS netgen
ARG NETGEN_REPO_URL="https://github.com/rtimothyedwards/netgen.git"
ARG NETGEN_REPO_COMMIT="1.5.295"
ARG NETGEN_NAME="netgen"
RUN --mount=type=bind,source=images/netgen,target=/images/netgen \
    bash /images/netgen/scripts/install.sh

#######################################################################
# Compile ngspice
#######################################################################
FROM open_pdks AS ngspice
ARG NGSPICE_REPO_URL="https://github.com/danchitnis/ngspice-sf-mirror.git"
ARG NGSPICE_REPO_COMMIT="ngspice-44.2"
ARG NGSPICE_NAME="ngspice"
RUN --mount=type=bind,source=images/ngspice,target=/images/ngspice \
    bash /images/ngspice/scripts/install.sh

#######################################################################
# Compile ngspyce
#######################################################################
FROM base-dev AS ngspyce
ARG NGSPYCE_REPO_URL="https://github.com/ignamv/ngspyce.git"
ARG NGSPYCE_REPO_COMMIT="154a2724080e3bf15827549bba9f315cd11984fe"
ARG NGSPYCE_NAME="ngspyce"
RUN --mount=type=bind,source=images/ngspyce,target=/images/ngspyce \
    bash /images/ngspyce/scripts/install.sh

#######################################################################
# Compile nvc (VHDL simulator)
#######################################################################
FROM base-dev AS nvc
ARG NVC_REPO_URL="https://github.com/nickg/nvc.git"
ARG NVC_REPO_COMMIT="r1.16.2"
ARG NVC_NAME="nvc"
RUN --mount=type=bind,source=images/nvc,target=/images/nvc \
    bash /images/nvc/scripts/install.sh

#######################################################################
# Compile openems
#######################################################################
FROM base-dev AS openems
ARG OPENEMS_REPO_URL="https://github.com/thliebig/openEMS-Project.git"
ARG OPENEMS_REPO_COMMIT="9ba6e1b330c2152e7f8d13bba4e42d834c9a432b"
ARG OPENEMS_NAME="openems"
RUN --mount=type=bind,source=images/openems,target=/images/openems \
    bash /images/openems/scripts/install.sh

#######################################################################
# Compile openroad
#######################################################################
FROM base-dev AS openroad_app
ARG OPENROAD_APP_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_APP_REPO_COMMIT="edf00dff99f6c40d67a30c0e22a8191c5d2ed9d6"
ARG OPENROAD_APP_NAME="openroad"
RUN --mount=type=bind,source=images/openroad,target=/images/openroad \
    bash /images/openroad/scripts/install.sh

#######################################################################
# Compile padring
#######################################################################
FROM base-dev AS padring
ARG PADRING_REPO_URL="https://github.com/iic-jku/padring.git"
ARG PADRING_REPO_COMMIT="17fba2638142baa4dc6e2a0b18cb1cd542017e16"
ARG PADRING_NAME="padring"
RUN --mount=type=bind,source=images/padring,target=/images/padring \
    bash /images/padring/scripts/install.sh

#######################################################################
# Compile pulp platform tools
#######################################################################
FROM base-dev AS pulp-tools
ARG PULP_NAME="pulp"
RUN --mount=type=bind,source=images/pulp-tools,target=/images/pulp-tools \
    bash /images/pulp-tools/scripts/install.sh

#######################################################################
# Compile pyopus
#######################################################################
#FROM base-dev AS pyopus
#ARG PYOPUS_REPO_URL="https://fides.fe.uni-lj.si/pyopus/download"
#ARG PYOPUS_REPO_COMMIT="0.11.2"
#ARG PYOPUS_NAME="pyopus"
#RUN --mount=type=bind,source=images/pyopus,target=/images/pyopus \
#    bash /images/pyopus/scripts/install.sh

#######################################################################
# Compile surelog
#######################################################################
FROM base-dev AS surelog
ARG SURELOG_REPO_URL="https://github.com/chipsalliance/Surelog.git"
ARG SURELOG_REPO_COMMIT="v1.84"
ARG SURELOG_NAME="surelog"
RUN --mount=type=bind,source=images/surelog,target=/images/surelog \
    bash /images/surelog/scripts/install.sh

#######################################################################
# Compile surfer
#######################################################################
FROM base-dev AS surfer
ARG SURFER_REPO_URL="https://gitlab.com/surfer-project/surfer.git"
ARG SURFER_REPO_COMMIT="v0.3.0"
ARG SURFER_NAME="surfer"
RUN --mount=type=bind,source=images/surfer,target=/images/surfer \
    bash /images/surfer/scripts/install.sh

#######################################################################
# Compile qflow helper files
#######################################################################
FROM base-dev AS qflow
ARG QFLOW_REPO_URL="https://github.com/RTimothyEdwards/qflow.git"
ARG QFLOW_REPO_COMMIT="52ecda1053bcbd2f6ec88b8379c8179e2a849f7a"
ARG QFLOW_NAME="qflow"
RUN --mount=type=bind,source=images/qflow,target=/images/qflow \
    bash /images/qflow/scripts/install.sh

#######################################################################
# Compile qucs-s
#######################################################################
FROM base-dev AS qucs-s
ARG QUCS_S_REPO_URL="https://github.com/ra3xdh/qucs_s.git"
ARG QUCS_S_REPO_COMMIT="25.1.2"
ARG QUCS_S_NAME="qucs-s"
RUN --mount=type=bind,source=images/qucs-s,target=/images/qucs-s \
    bash /images/qucs-s/scripts/install.sh

#######################################################################
# Compile riscv-gnu-toolchain
#######################################################################
FROM base-dev AS riscv-gnu-toolchain
ARG RISCV_GNU_TOOLCHAIN_REPO_URL="https://github.com/riscv-collab/riscv-gnu-toolchain.git"
ARG RISCV_GNU_TOOLCHAIN_REPO_COMMIT="2025.07.03"
ARG RISCV_GNU_TOOLCHAIN_NAME="riscv-gnu-toolchain"
RUN --mount=type=bind,source=images/riscv-gnu-toolchain,target=/images/riscv-gnu-toolchain \
    bash /images/riscv-gnu-toolchain/scripts/install.sh
ENV RISCV=$TOOLS/$RISCV_GNU_TOOLCHAIN_NAME

#######################################################################
# Compile riscv-pk (RISCV proxy kernel and boot loader)
#######################################################################
FROM riscv-gnu-toolchain AS riscv-pk
ARG RISCV_PK_REPO_URL="https://github.com/riscv-software-src/riscv-pk.git"
ARG RISCV_PK_REPO_COMMIT="0239d921a2b06c931736e55462ba50233763ee33"
ARG RISCV_PK_NAME="riscv-pk"
RUN --mount=type=bind,source=images/riscv-pk,target=/images/riscv-pk \
    bash /images/riscv-pk/scripts/install.sh

#######################################################################
# Compile slang
#######################################################################
FROM base-dev AS slang
ARG SLANG_REPO_URL="https://github.com/MikePopoloski/slang.git"
ARG SLANG_REPO_COMMIT="66fa94a4862e6dd49c32036b57eaa1d3a76b6c29"
ARG SLANG_NAME="slang"
RUN --mount=type=bind,source=images/slang,target=/images/slang \
    bash /images/slang/scripts/install.sh

#######################################################################
# Compile spike (RISCV ISA simulator)
#######################################################################
FROM riscv-gnu-toolchain AS spike
ARG SPIKE_REPO_URL="https://github.com/riscv-software-src/riscv-isa-sim.git"
ARG SPIKE_REPO_COMMIT="965547260a803a77d10f8f628bda61bea4b1464f"
ARG SPIKE_NAME="spike"
RUN --mount=type=bind,source=images/spike,target=/images/spike \
    bash /images/spike/scripts/install.sh

#######################################################################
# Compile vacask
#######################################################################
FROM openvaf AS vacask
ARG VACASK_REPO_URL="https://codeberg.org/arpadbuermen/VACASK.git"
ARG VACASK_REPO_COMMIT="_0.3.0"
ARG VACASK_NAME="vacask"
RUN --mount=type=bind,source=images/vacask,target=/images/vacask \
    bash /images/vacask/scripts/install.sh

#######################################################################
# Compile verilator
#######################################################################
FROM base-dev AS verilator
ARG VERILATOR_REPO_URL="https://github.com/verilator/verilator.git"
ARG VERILATOR_REPO_COMMIT="v5.036"
ARG VERILATOR_NAME="verilator"
RUN --mount=type=bind,source=images/verilator,target=/images/verilator \
    bash /images/verilator/scripts/install.sh

#######################################################################
# Compile veryl
#######################################################################
FROM base-dev AS veryl
ARG VERYL_NAME="veryl"
RUN --mount=type=bind,source=images/veryl,target=/images/veryl \
    bash /images/veryl/scripts/install.sh

#######################################################################
# Compile xcircuit
#######################################################################
FROM base-dev AS xcircuit
ARG XCIRCUIT_REPO_URL="https://github.com/RTimothyEdwards/XCircuit.git"
ARG XCIRCUIT_REPO_COMMIT="b67fb820ac5506f9926ebc7f92c65c74c48e087d"
ARG XCIRCUIT_NAME="xcircuit"
RUN --mount=type=bind,source=images/xcircuit,target=/images/xcircuit \
    bash /images/xcircuit/scripts/install.sh

#######################################################################
# Compile xschem
#######################################################################
FROM base-dev AS xschem
ARG XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem.git"
ARG XSCHEM_REPO_COMMIT="8fe82cf4ce11eac524b3990db225ce0d4f394012"
ARG XSCHEM_NAME="xschem"
RUN --mount=type=bind,source=images/xschem,target=/images/xschem \
    bash /images/xschem/scripts/install.sh

#######################################################################
# Compile yosys & ghdl plugin & slang plugin
#######################################################################
FROM base-dev AS yosys
ARG YOSYS_REPO_URL="https://github.com/YosysHQ/yosys.git"
ARG YOSYS_REPO_COMMIT="v0.54"
ARG YOSYS_NAME="yosys"
ARG YOSYS_EQY_REPO_URL="https://github.com/YosysHQ/eqy.git"
ARG YOSYS_EQY_NAME="yosys_eqy"
ARG YOSYS_SBY_REPO_URL="https://github.com/YosysHQ/sby.git"
ARG YOSYS_SBY_NAME="yosys_sby"
ARG YOSYS_MCY_REPO_URL="https://github.com/YosysHQ/mcy.git"
ARG YOSYS_MCY_NAME="yosys_mcy"
RUN --mount=type=bind,source=images/yosys,target=/images/yosys \
    bash /images/yosys/scripts/install.sh

FROM base-dev AS ghdl-yosys-plugin
ARG GHDL_YOSYS_PLUGIN_REPO_URL="https://github.com/ghdl/ghdl-yosys-plugin.git"
ARG GHDL_YOSYS_PLUGIN_REPO_COMMIT="1b97dc71377cea7e861be6625be4353c377a5fb5"
ARG GHDL_YOSYS_PLUGIN_NAME="ghdl-yosys-plugin"
COPY --from=yosys	${TOOLS}    ${TOOLS}
COPY --from=ghdl	${TOOLS}    ${TOOLS}
RUN --mount=type=bind,source=images/ghdl-yosys-plugin,target=/images/ghdl-yosys-plugin \
    bash /images/ghdl-yosys-plugin/scripts/install.sh

FROM base-dev AS slang-yosys-plugin
ARG SLANG_YOSYS_PLUGIN_REPO_URL="https://github.com/povik/yosys-slang.git"
ARG SLANG_YOSYS_PLUGIN_REPO_COMMIT="9d9ce7b767d2ea776e2dee0ef636a84512e6b229"
ARG SLANG_YOSYS_PLUGIN_NAME="slang-yosys-plugin"
COPY --from=yosys	${TOOLS}    ${TOOLS}
RUN --mount=type=bind,source=images/slang-yosys-plugin,target=/images/slang-yosys-plugin \
    bash /images/slang-yosys-plugin/scripts/install.sh

#######################################################################
# Compile different components for the rftoolkit
#######################################################################
FROM base-dev AS rftoolkit
ARG RFTK_NAME="rftoolkit"
ARG RFTK_FASTHENRY_REPO_URL="https://github.com/ediloren/FastHenry2.git"
ARG RFTK_FASTHENRY_REPO_COMMIT="363e43ed57ad3b9affa11cba5a86624fad0edaa9"
ARG RFTK_FASTERCAP_REPO_URL="https://github.com/ediloren/FasterCap.git"
ARG RFTK_FASTERCAP_REPO_COMMIT="b42179a8fdd25ab42fe45527282b4a738d7e7f87"
RUN --mount=type=bind,source=images/rftoolkit,target=/images/rftoolkit \
    bash /images/rftoolkit/scripts/install.sh

#######################################################################
# Final output container
#######################################################################
FROM ${BASE_IMAGE} AS iic-osic-tools

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
COPY --from=kactus                       ${TOOLS}/              ${TOOLS}/
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

# Install all APT and PIP packages, as well as noVNC from sources
RUN $STARTUPDIR/scripts/install.sh

# Install examples
#RUN git clone --depth=1 https://github.com/iic-jku/SKY130_SAR-ADC1.git ${EXAMPLES}/SKY130_SAR-ADC1 && \
#    git clone --depth=1 https://github.com/iic-jku/SKY130_PLL1.git ${EXAMPLES}/SKY130_PLL1 && \
#    git clone --depth=1 https://github.com/mabrains/Analog_blocks.git ${EXAMPLES}/SKY130_ANALOG-BLOCKS
RUN git clone --depth=1 https://github.com/mole99/ota-5t.git ${EXAMPLES}/cace/ota-5t && \
    git clone --depth=1 https://github.com/iic-jku/analog-circuit-design ${EXAMPLES}/analog-course 
