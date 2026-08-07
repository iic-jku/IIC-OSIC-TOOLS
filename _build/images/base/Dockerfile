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
# noVNC webport, connect via http://IP:80/?password=abc123 (the password is VNC_PW below)
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
# OpenMPI (used by palace and Xyce) defaults to CMA for shared-memory transfers,
# which needs the SYS_PTRACE capability the container does not have; without
# this it prints errors on every run. Not a defect, a permanent container
# constraint. Note: the "vader" BTL is OpenMPI 4.x (noble ships 4.1.6); with
# OpenMPI >= 5 the knob is called OMPI_MCA_btl_sm_single_copy_mechanism.
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
# index.html is the redirect page written by 80_install_apps.sh; it declares no icons at all,
# so the root URL falls back to /favicon.ico (it also carries its own branded <title>, and so
# is not part of the title substitution below). vnc.html, which it redirects to, declares 13
# sized PNGs plus an SVG icon that browsers prefer over all of them, so all of those are
# replaced too.
# No --chmod here: it would also apply to the directories and make them non-traversable.
# The modes are normalized in the RUN below instead -- COPY carries the modes of the build
# context, so with a umask of 027 on the build host the copied files land unreadable for the
# container user, and the directories COPY touches on the way (`app`, `app/images`) lose
# their o+x as well, which takes the whole upstream `app/` tree (ui.js, styles, locale) with
# them. websockify answers those with a 404, so vnc.html would come up unstyled and never
# connect.
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
    sed -i 's|const PAGE_TITLE = "noVNC";|const PAGE_TITLE = "IIC-OSIC-TOOLS";|' /usr/share/novnc/app/ui.js; \
    chmod -R a+rX /usr/share/novnc

# Rebrand the JupyterLab favicons. Like the noVNC block above this must stay after the RUN,
# since jupyter_server is pip-installed there. JupyterLab's page references
# `static/favicons/favicon.ico` (idle) and `.../favicon-busy-1.ico` (busy), both served out
# of jupyter_server's package directory. The busy icons keep an inverted tile so the
# "kernel is working" cue survives the rebrand.
# The destination is resolved from the installed package rather than hardcoding the Python
# version, and the build fails if the upstream layout moves.
COPY images/base/branding/jupyter/ /usr/share/iic-osic-tools/branding/jupyter/
RUN set -eu; \
    JUPYTER_STATIC="$(python3 -c 'import jupyter_server, os; print(os.path.join(os.path.dirname(jupyter_server.__file__), "static"))')"; \
    [ -f "$JUPYTER_STATIC/favicons/favicon.ico" ] || \
        { echo "ERROR: $JUPYTER_STATIC/favicons/favicon.ico not found - jupyter_server layout changed?" >&2; exit 1; }; \
    cp -f /usr/share/iic-osic-tools/branding/jupyter/favicon.ico "$JUPYTER_STATIC/favicon.ico"; \
    cp -f /usr/share/iic-osic-tools/branding/jupyter/favicons/*.ico "$JUPYTER_STATIC/favicons/"; \
    chmod -R a+rX "$JUPYTER_STATIC"

# Finalize setup/install
WORKDIR ${DESIGNS}
ENTRYPOINT ["/dockerstartup/scripts/ui_startup.sh"]
CMD ["--wait"]
