# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
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

# Rebrand the noVNC web assets. This MUST stay after the RUN above: the `novnc` apt package
# installs into /usr/share/novnc and would overwrite anything placed there by the
# `COPY images/base/skel /` near the top of this file.
# index.html is a symlink to vnc_lite.html, which declares no icons at all, so the root URL
# falls back to /favicon.ico. vnc.html declares 13 sized PNGs plus an SVG icon that browsers
# prefer over all of them, so all of those are replaced too.
# No --chmod here: it would also apply to the directories and make them non-traversable.
COPY images/base/branding/novnc/ /usr/share/novnc/

# Rebrand the noVNC browser-tab title. There are three independent sources: the static
# <title> in each entry page, plus PAGE_TITLE in app/ui.js, which vnc.html's JS uses to
# rewrite document.title once connected ("<desktop name> - <PAGE_TITLE>"). Patching only
# the <title> tags would leave "noVNC" in the tab as soon as the session connects.
# Each substitution is guarded so that an upstream noVNC change fails the build loudly
# instead of silently shipping the stock branding.
RUN set -eu; \
    for f in /usr/share/novnc/vnc.html /usr/share/novnc/vnc_lite.html; do \
        grep -q '<title>noVNC</title>' "$f" || \
            { echo "ERROR: <title>noVNC</title> not found in $f - did noVNC change?" >&2; exit 1; }; \
        sed -i 's|<title>noVNC</title>|<title>IIC-OSIC-TOOLS</title>|' "$f"; \
    done; \
    grep -q 'const PAGE_TITLE = "noVNC";' /usr/share/novnc/app/ui.js || \
        { echo "ERROR: PAGE_TITLE not found in app/ui.js - did noVNC change?" >&2; exit 1; }; \
    sed -i 's|const PAGE_TITLE = "noVNC";|const PAGE_TITLE = "IIC-OSIC-TOOLS";|' /usr/share/novnc/app/ui.js

# Finalize setup/install
WORKDIR ${DESIGNS}
ENTRYPOINT ["/dockerstartup/scripts/ui_startup.sh"]
CMD ["--wait"]
