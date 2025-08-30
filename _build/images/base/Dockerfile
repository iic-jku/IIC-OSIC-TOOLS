#######################################################################
# Setup base image
#######################################################################
ARG BASE_IMAGE=ubuntu:noble
FROM ${BASE_IMAGE} AS base
ENV DEBIAN_FRONTEND=noninteractive \
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
    bash /images/base/scripts/72_install_adms.sh && \
    bash /images/base/scripts/73_install_bottleneck.sh

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

# Copy skeleton
COPY images/iic-osic-tools/skel_base /

# Allow scripts to be executed by any user
RUN find $STARTUPDIR/scripts -name '*.sh' -exec chmod a+x {} +

# Install all APT and PIP packages, as well as noVNC from sources
RUN $STARTUPDIR/scripts/install.sh

# Finalize setup/install
RUN $STARTUPDIR/scripts/post_install.sh

# Install examples
#RUN git clone --depth=1 https://github.com/iic-jku/SKY130_SAR-ADC1.git ${EXAMPLES}/SKY130_SAR-ADC1 && \
#    git clone --depth=1 https://github.com/iic-jku/SKY130_PLL1.git ${EXAMPLES}/SKY130_PLL1 && \
#    git clone --depth=1 https://github.com/mabrains/Analog_blocks.git ${EXAMPLES}/SKY130_ANALOG-BLOCKS
RUN git clone --depth=1 https://github.com/mole99/ota-5t.git ${EXAMPLES}/cace/ota-5t && \
    git clone --depth=1 https://github.com/iic-jku/analog-circuit-design ${EXAMPLES}/analog-course


WORKDIR ${DESIGNS}
USER 1000:1000
ENTRYPOINT ["/dockerstartup/scripts/ui_startup.sh"]
CMD ["--wait"]
