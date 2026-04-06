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

# Copy base skeleton into image
COPY images/base/skel /

RUN --mount=type=bind,source=images/base,target=/images/base \
    bash /images/base/scripts/00_base_install.sh && \
    bash /images/base/scripts/01_base_setup.sh && \
    bash /images/base/scripts/30_install_boost.sh && \
    bash /images/base/scripts/31_install_or-tools.sh && \
    bash /images/base/scripts/32_install_cudd.sh && \
    bash /images/base/scripts/33_install_gtest.sh && \
    bash /images/base/scripts/34_install_spdlog.sh && \
    bash /images/base/scripts/35_install_lemon.sh && \
    bash /images/base/scripts/70_install_from_pip.sh && \
    bash /images/base/scripts/71_fix_gobject_introspection.sh && \
    bash /images/base/scripts/72_install_adms.sh && \
    bash /images/base/scripts/80_install_apps.sh && \
    bash /images/base/scripts/99_base_finalize.sh && \
    rm -rf *.usr-is-merged && \
    chmod -R 755 /dockerstartup && \
    chmod 644 /etc/profile.d/iic*.sh && \
    chmod -R 777 /headless && \
    find /headless -type f -not -name "*.sh" -exec chmod 666 {} \;

# Finalize setup/install
WORKDIR ${DESIGNS}
ENTRYPOINT ["/dockerstartup/scripts/ui_startup.sh"]
CMD ["--wait"]
