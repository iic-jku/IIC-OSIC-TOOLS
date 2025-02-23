#######################################################################
# Setup base image
#######################################################################
ARG BASE_IMAGE=ubuntu:noble
FROM ${BASE_IMAGE} AS base
ARG CONTAINER_TAG=unknown
ENV IIC_OSIC_TOOLS_VERSION=${CONTAINER_TAG} \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Vienna \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    TOOLS=/foss/tools \
    PDK_ROOT=/foss/pdks \
    DESIGNS=/foss/designs \
    EXAMPLES=/foss/examples
RUN --mount=type=bind,source=images/base,target=/images/base \
    bash /images/base/scripts/00_base_install.sh && \
    bash /images/base/scripts/01_base_setup.sh && \
    bash /images/base/scripts/30_install_boost.sh && \
    bash /images/base/scripts/31_install_or-tools.sh && \
    bash /images/base/scripts/32_install_cudd.sh && \
    bash /images/base/scripts/33_install_gtest.sh && \
    bash /images/base/scripts/34_install_spdlog.sh && \
    bash /images/base/scripts/70_install_from_pip.sh && \
    bash /images/base/scripts/71_fix_gobject_introspection.sh && \
    bash /images/base/scripts/72_install_adms.sh

#######################################################################
# Add base packages (install via pip, npm, or gem)
#######################################################################
FROM base AS basepkg
RUN --mount=type=bind,source=images/base,target=/images/base \
    bash /images/base/scripts/90_basepkg_install.sh && \
    bash /images/base/scripts/91_install_bottleneck.sh

#######################################################################
# Compile magic
#######################################################################
FROM basepkg AS magic
ARG MAGIC_REPO_URL="https://github.com/rtimothyedwards/magic.git"
ARG MAGIC_REPO_COMMIT="8.3.520"
ARG MAGIC_NAME="magic"
COPY images/magic/scripts/install.sh install.sh
RUN --mount=type=bind,source=images/magic,target=/images/magic \
    bash /images/magic/scripts/install.sh

#######################################################################
# Compile openvaf
#######################################################################
FROM basepkg AS openvaf
ARG OPENVAF_REPO_URL="https://github.com/dwarning/OpenVAF.git"
ARG OPENVAF_REPO_COMMIT="2ab0d05fcf9ffd21cc5f49022b7624224cb96b1f"
ARG OPENVAF_NAME="openvaf"
ENV OPENVAF_NAME=${OPENVAF_NAME}
RUN --mount=type=bind,source=images/openvaf,target=/images/openvaf \
    bash /images/openvaf/scripts/install.sh

#######################################################################
# Compile osic-multitool
#######################################################################
FROM basepkg AS osic-multitool
ARG OSIC_MULTITOOL_REPO_URL="https://github.com/iic-jku/osic-multitool.git"
ARG OSIC_MULTITOOL_REPO_COMMIT="cc61d2dcad01491a6256097761b6c25f2809be63"
ARG OSIC_MULTITOOL_NAME="osic-multitool"
RUN --mount=type=bind,source=images/osic-multitool,target=/images/osic-multitool \
    bash /images/osic-multitool/scripts/install.sh

#######################################################################
# Compile xyce & xyce-xdm
#######################################################################
FROM base AS xyce
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
    bash /images/open_pdks/scripts/install_volare.sh
RUN --mount=type=bind,source=images/open_pdks,target=/images/open_pdks \
    bash /images/open_pdks/scripts/install_ihp.sh

#######################################################################
# Compile covered 
#######################################################################
FROM base AS covered
ARG COVERED_REPO_URL="https://github.com/hpretl/verilog-covered.git"
ARG COVERED_REPO_COMMIT="19d30fc942642b14dc24e95331cd4777c8dcbad9"
ARG COVERED_NAME="covered"
RUN --mount=type=bind,source=images/covered,target=/images/covered \
    bash /images/covered/scripts/install.sh

#######################################################################
# Compile cvc_rv
#######################################################################
FROM base AS cvc_rv
ARG CVC_RV_REPO_URL="https://github.com/d-m-bailey/cvc.git"
ARG CVC_RV_REPO_COMMIT="ced5a2e6d5e8656180d404e9220349e87512c82f"
ARG CVC_RV_NAME="cvc_rv"
RUN --mount=type=bind,source=images/cvc_rv,target=/images/cvc_rv \
    bash /images/cvc_rv/scripts/install.sh

#######################################################################
# Compile gaw3-xschem
#######################################################################
FROM base AS gaw3-xschem
ARG GAW3_XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem-gaw.git"
ARG GAW3_XSCHEM_REPO_COMMIT="d41828de08eef29c2f937d363bc2ecdc2687bfae"
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
FROM base AS ghdl
ARG GHDL_REPO_URL="https://github.com/ghdl/ghdl.git"
ARG GHDL_REPO_COMMIT="1fdd5fc62e7529c6030a834f9bc922b3a28ffef7"
ARG GHDL_NAME="ghdl"
RUN --mount=type=bind,source=images/ghdl,target=/images/ghdl \
    bash /images/ghdl/scripts/install.sh

#######################################################################
# Compile gtkwave
#######################################################################
FROM base AS gtkwave
ARG GTKWAVE_REPO_URL="https://github.com/gtkwave/gtkwave.git"
ARG GTKWAVE_REPO_COMMIT="4435a9ef89892757eaf703085606f10040da6bfe"
ARG GTKWAVE_NAME="gtkwave"
RUN --mount=type=bind,source=images/gtkwave,target=/images/gtkwave \
    bash /images/gtkwave/scripts/install.sh

#######################################################################
# Compile irsim
#######################################################################
FROM base AS irsim
ARG IRSIM_REPO_URL="https://github.com/rtimothyedwards/irsim.git"
ARG IRSIM_REPO_COMMIT="a7884acc04cd94017779893d381b7e93d8895587"
ARG IRSIM_NAME="irsim"
RUN --mount=type=bind,source=images/irsim,target=/images/irsim \
    bash /images/irsim/scripts/install.sh

#######################################################################
# Compile iverilog
#######################################################################
FROM base AS iverilog
ARG IVERILOG_REPO_URL="https://github.com/steveicarus/iverilog.git"
ARG IVERILOG_REPO_COMMIT="99580cd05171b82e3b460c96abdfbfafbcfd9d60"
ARG IVERILOG_NAME="iverilog"
RUN --mount=type=bind,source=images/iverilog,target=/images/iverilog \
    bash /images/iverilog/scripts/install.sh

#######################################################################
# Compile klayout
#######################################################################
FROM basepkg AS klayout
ARG KLAYOUT_REPO_URL="https://github.com/KLayout/klayout.git"
ARG KLAYOUT_REPO_COMMIT="v0.29.11"
ARG KLAYOUT_NAME="klayout"
RUN --mount=type=bind,source=images/klayout,target=/images/klayout \
    bash /images/klayout/scripts/install.sh

#######################################################################
# Compile libman
#######################################################################
FROM base AS libman
ARG LIBMAN_REPO_URL="https://github.com/IHP-GmbH/LibMan.git"
ARG LIBMAN_REPO_COMMIT="a4537c1fba19966e80408a7b224001d5697ff1e6"
ARG LIBMAN_NAME="libman"
RUN --mount=type=bind,source=images/libman,target=/images/libman \
    bash /images/libman/scripts/install.sh

#######################################################################
# Compile netgen
#######################################################################
FROM base AS netgen
ARG NETGEN_REPO_URL="https://github.com/rtimothyedwards/netgen.git"
ARG NETGEN_REPO_COMMIT="1.5.292"
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
FROM basepkg AS ngspyce
ARG NGSPYCE_REPO_URL="https://github.com/ignamv/ngspyce.git"
ARG NGSPYCE_REPO_COMMIT="154a2724080e3bf15827549bba9f315cd11984fe"
ARG NGSPYCE_NAME="ngspyce"
RUN --mount=type=bind,source=images/ngspyce,target=/images/ngspyce \
    bash /images/ngspyce/scripts/install.sh

#######################################################################
# Compile nvc (VHDL simulator)
#######################################################################
FROM base AS nvc
ARG NVC_REPO_URL="https://github.com/nickg/nvc.git"
ARG NVC_REPO_COMMIT="r1.15.1"
ARG NVC_NAME="nvc"
RUN --mount=type=bind,source=images/nvc,target=/images/nvc \
    bash /images/nvc/scripts/install.sh

#######################################################################
# Compile openroad
#######################################################################
FROM base AS openroad_app
ARG OPENROAD_APP_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_APP_REPO_COMMIT="edf00dff99f6c40d67a30c0e22a8191c5d2ed9d6"
ARG OPENROAD_APP_NAME="openroad"
RUN --mount=type=bind,source=images/openroad,target=/images/openroad \
    bash /images/openroad/scripts/install.sh

#######################################################################
# Compile padring
#######################################################################
FROM base AS padring
ARG PADRING_REPO_URL="https://github.com/iic-jku/padring.git"
ARG PADRING_REPO_COMMIT="17fba2638142baa4dc6e2a0b18cb1cd542017e16"
ARG PADRING_NAME="padring"
RUN --mount=type=bind,source=images/padring,target=/images/padring \
    bash /images/padring/scripts/install.sh

#######################################################################
# Compile pulp platform tools
#######################################################################
FROM base AS pulp-tools
ARG PULP_NAME="pulp"
RUN --mount=type=bind,source=images/pulp-tools,target=/images/pulp-tools \
    bash /images/pulp-tools/scripts/install.sh

#######################################################################
# Compile pyopus
#######################################################################
#FROM basepkg AS pyopus
#ARG PYOPUS_REPO_URL="https://fides.fe.uni-lj.si/pyopus/download"
#ARG PYOPUS_REPO_COMMIT="0.11.2"
#ARG PYOPUS_NAME="pyopus"
#RUN --mount=type=bind,source=images/pyopus,target=/images/pyopus \
#    bash /images/pyopus/scripts/install.sh

#######################################################################
# Compile surelog
#######################################################################
FROM base AS surelog
ARG SURELOG_REPO_URL="https://github.com/chipsalliance/Surelog.git"
ARG SURELOG_REPO_COMMIT="v1.84"
ARG SURELOG_NAME="surelog"
RUN --mount=type=bind,source=images/surelog,target=/images/surelog \
    bash /images/surelog/scripts/install.sh

#######################################################################
# Compile surfer
#######################################################################
FROM base AS surfer
ARG SURFER_REPO_URL="https://gitlab.com/surfer-project/surfer"
ARG SURFER_REPO_COMMIT="v0.3.0"
ARG SURFER_NAME="surfer"
RUN --mount=type=bind,source=images/surfer,target=/images/surfer \
    bash /images/surfer/scripts/install.sh

#######################################################################
# Compile qflow helper files
#######################################################################
FROM base AS qflow
ARG QFLOW_REPO_URL="https://github.com/RTimothyEdwards/qflow.git"
ARG QFLOW_REPO_COMMIT="52ecda1053bcbd2f6ec88b8379c8179e2a849f7a"
ARG QFLOW_NAME="qflow"
RUN --mount=type=bind,source=images/qflow,target=/images/qflow \
    bash /images/qflow/scripts/install.sh

#######################################################################
# Compile qucs-s
#######################################################################
FROM base AS qucs-s
ARG QUCS_S_REPO_URL="https://github.com/ra3xdh/qucs_s.git"
ARG QUCS_S_REPO_COMMIT="25.1.0"
ARG QUCS_S_NAME="qucs-s"
RUN --mount=type=bind,source=images/qucs-s,target=/images/qucs-s \
    bash /images/qucs-s/scripts/install.sh

#######################################################################
# Compile riscv-gnu-toolchain
#######################################################################
FROM base AS riscv-gnu-toolchain
ARG RISCV_GNU_TOOLCHAIN_REPO_URL="https://github.com/riscv-collab/riscv-gnu-toolchain.git"
ARG RISCV_GNU_TOOLCHAIN_REPO_COMMIT="2025.01.20"
ARG RISCV_GNU_TOOLCHAIN_NAME="riscv-gnu-toolchain"
RUN --mount=type=bind,source=images/riscv-gnu-toolchain,target=/images/riscv-gnu-toolchain \
    bash /images/riscv-gnu-toolchain/scripts/install.sh
ENV RISCV=$TOOLS/$RISCV_GNU_TOOLCHAIN_NAME

#######################################################################
# Compile riscv-pk (RISCV proxy kernel and boot loader)
#######################################################################
FROM riscv-gnu-toolchain AS riscv-pk
ARG RISCV_PK_REPO_URL="https://github.com/riscv-software-src/riscv-pk.git"
ARG RISCV_PK_REPO_COMMIT="e5563d1044bd6790325c4602c49f89e1182fa91a"
ARG RISCV_PK_NAME="riscv-pk"
RUN --mount=type=bind,source=images/riscv-pk,target=/images/riscv-pk \
    bash /images/riscv-pk/scripts/install.sh

#######################################################################
# Compile slang
#######################################################################
FROM base AS slang
ARG SLANG_REPO_URL="https://github.com/MikePopoloski/slang.git"
ARG SLANG_REPO_COMMIT="f9d888a5ea817818322b70f15fe97330ad9393b5"
ARG SLANG_NAME="slang"
RUN --mount=type=bind,source=images/slang,target=/images/slang \
    bash /images/slang/scripts/install.sh

#######################################################################
# Compile verilator
#######################################################################
FROM base AS verilator
ARG VERILATOR_REPO_URL="https://github.com/verilator/verilator.git"
ARG VERILATOR_REPO_COMMIT="v5.032"
ARG VERILATOR_NAME="verilator"
RUN --mount=type=bind,source=images/verilator,target=/images/verilator \
    bash /images/verilator/scripts/install.sh

#######################################################################
# Compile xcircuit
#######################################################################
FROM base AS xcircuit
ARG XCIRCUIT_REPO_URL="https://github.com/RTimothyEdwards/XCircuit.git"
ARG XCIRCUIT_REPO_COMMIT="b6d0b096a6a4730a4255efb50191e03cfa9b5496"
ARG XCIRCUIT_NAME="xcircuit"
RUN --mount=type=bind,source=images/xcircuit,target=/images/xcircuit \
    bash /images/xcircuit/scripts/install.sh

#######################################################################
# Compile xschem
#######################################################################
FROM base AS xschem
ARG XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem.git"
ARG XSCHEM_REPO_COMMIT="e266642c2c80021efd5437349ae7ca12b875d00c"
ARG XSCHEM_NAME="xschem"
RUN --mount=type=bind,source=images/xschem,target=/images/xschem \
    bash /images/xschem/scripts/install.sh

#######################################################################
# Compile yosys & ghdl plugin & slang plugin
#######################################################################
FROM base AS yosys
ARG YOSYS_REPO_URL="https://github.com/YosysHQ/yosys.git"
ARG YOSYS_REPO_COMMIT="v0.50"
ARG YOSYS_NAME="yosys"
ARG YOSYS_EQY_REPO_URL="https://github.com/YosysHQ/eqy.git"
ARG YOSYS_EQY_NAME="yosys_eqy"
ARG YOSYS_SBY_REPO_URL="https://github.com/YosysHQ/sby.git"
ARG YOSYS_SBY_NAME="yosys_sby"
ARG YOSYS_MCY_REPO_URL="https://github.com/YosysHQ/mcy.git"
ARG YOSYS_MCY_NAME="yosys_mcy"
RUN --mount=type=bind,source=images/yosys,target=/images/yosys \
    bash /images/yosys/scripts/install.sh

FROM base AS ghdl-yosys-plugin
ARG GHDL_YOSYS_PLUGIN_REPO_URL="https://github.com/ghdl/ghdl-yosys-plugin.git"
ARG GHDL_YOSYS_PLUGIN_REPO_COMMIT="4ea20ad3f1c1177b912a93308a8e926d5981792d"
ARG GHDL_YOSYS_PLUGIN_NAME="ghdl-yosys-plugin"
COPY --from=yosys	${TOOLS}    ${TOOLS}
COPY --from=ghdl	${TOOLS}    ${TOOLS}
RUN --mount=type=bind,source=images/ghdl-yosys-plugin,target=/images/ghdl-yosys-plugin \
    bash /images/ghdl-yosys-plugin/scripts/install.sh

FROM base AS slang-yosys-plugin
ARG SLANG_YOSYS_PLUGIN_REPO_URL="https://github.com/povik/yosys-slang.git"
ARG SLANG_YOSYS_PLUGIN_REPO_COMMIT="0366b32fa27305d0581031c29536b9725df28d4c"
ARG SLANG_YOSYS_PLUGIN_NAME="slang-yosys-plugin"
COPY --from=yosys	${TOOLS}    ${TOOLS}
RUN --mount=type=bind,source=images/slang-yosys-plugin,target=/images/slang-yosys-plugin \
    bash /images/slang-yosys-plugin/scripts/install.sh

#######################################################################
# Compile different components for the rftoolkit
#######################################################################
FROM base AS rftoolkit
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
FROM basepkg AS iic-osic-tools

# Connection ports for controlling the UI:
# VNC port:5901
# noVNC webport, connect via http://IP:80/?password=start
ENV VNC_PORT=5901 \
    NO_VNC_PORT=80 \
    JUPYTER_PORT=8888
EXPOSE $VNC_PORT $NO_VNC_PORT $JUPYTER_PORT

# Environment config
ENV HOME=/headless \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    NO_VNC_HOME=/usr/share/novnc \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1680x1050 \
    VNC_PW=abc123 \
    VNC_VIEW_ONLY=false
#FIXME workaround for OpenMPI throwing errors when run inside a container without Capability "SYS_PTRACE".
ENV OMPI_MCA_btl_vader_single_copy_mechanism=none

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
COPY --from=klayout                      ${TOOLS}/              ${TOOLS}/
COPY --from=libman                       ${TOOLS}/              ${TOOLS}/
COPY --from=magic                        ${TOOLS}/              ${TOOLS}/
COPY --from=netgen                       ${TOOLS}/              ${TOOLS}/
COPY --from=nvc                          ${TOOLS}/              ${TOOLS}/
COPY --from=ngspice                      ${TOOLS}/              ${TOOLS}/
COPY --from=ngspyce                      ${TOOLS}/              ${TOOLS}/
COPY --from=openroad_app                 ${TOOLS}/              ${TOOLS}/
COPY --from=osic-multitool               ${TOOLS}/              ${TOOLS}/
COPY --from=openvaf                      ${TOOLS}/              ${TOOLS}/
COPY --from=padring                      ${TOOLS}/              ${TOOLS}/
COPY --from=pulp-tools                   ${TOOLS}/              ${TOOLS}/
#FIXME COPY --from=pyopus                       ${TOOLS}/              ${TOOLS}/
COPY --from=qflow                        ${TOOLS}/              ${TOOLS}/
COPY --from=qucs-s                       ${TOOLS}/              ${TOOLS}/
COPY --from=rftoolkit                    ${TOOLS}/              ${TOOLS}/
COPY --from=riscv-gnu-toolchain          ${TOOLS}/              ${TOOLS}/
COPY --from=riscv-pk                     ${TOOLS}/              ${TOOLS}/
COPY --from=slang                        ${TOOLS}/              ${TOOLS}/
COPY --from=surelog                      ${TOOLS}/              ${TOOLS}/
COPY --from=surfer                       ${TOOLS}/              ${TOOLS}/
COPY --from=verilator                    ${TOOLS}/              ${TOOLS}/
COPY --from=xcircuit                     ${TOOLS}/              ${TOOLS}/
COPY --from=xschem                       ${TOOLS}/              ${TOOLS}/
COPY --from=xyce                         ${TOOLS}/              ${TOOLS}/
COPY --from=xyce-xdm                     ${TOOLS}/              ${TOOLS}/
COPY --from=yosys                        ${TOOLS}/              ${TOOLS}/
COPY --from=ghdl-yosys-plugin            ${TOOLS}_add/          ${TOOLS}/
COPY --from=slang-yosys-plugin           ${TOOLS}_add/          ${TOOLS}/

# Copy skeleton and tool version file
COPY images/iic-osic-tools/skel /
COPY tool_metadata.yml /

# Allow scripts to be executed by any user
RUN find $STARTUPDIR/scripts -name '*.sh' -exec chmod a+x {} +

# Install all APT and PIP packages, as well as noVNC from sources
RUN $STARTUPDIR/scripts/install.sh

# Install examples
#RUN git clone --depth=1 https://github.com/iic-jku/SKY130_SAR-ADC1.git ${EXAMPLES}/SKY130_SAR-ADC1 && \
#    git clone --depth=1 https://github.com/iic-jku/SKY130_PLL1.git ${EXAMPLES}/SKY130_PLL1 && \
#    git clone --depth=1 https://github.com/mabrains/Analog_blocks.git ${EXAMPLES}/SKY130_ANALOG-BLOCKS
RUN git clone --depth=1 https://github.com/mole99/ota-5t.git ${EXAMPLES}/cace/ota-5t && \
    git clone --depth=1 https://github.com/iic-jku/analog-circuit-design ${EXAMPLES}/analog-course 

# Finalize setup/install
RUN $STARTUPDIR/scripts/post_install.sh

WORKDIR ${DESIGNS}
USER 1000:1000
ENTRYPOINT ["/dockerstartup/scripts/ui_startup.sh"]
CMD ["--wait"]
