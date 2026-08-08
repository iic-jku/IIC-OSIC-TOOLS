#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e
set -u

UBUNTU_CODENAME=$(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release | sed 's/"//g')

echo "[INFO] Adding repositories and installing misc. packages"

echo "[INFO] Adding Mozilla PPA"
GNUPG_PROXY_OPTION=""
if [[ ${http_proxy:-"unset"} != "unset" ]]; then
    GNUPG_PROXY_OPTION="--keyserver-options http-proxy=$http_proxy"
elif [[ ${https_proxy:-"unset"} != "unset" ]]; then
    GNUPG_PROXY_OPTION="--keyserver-options http-proxy=$https_proxy"
fi
GNUPGHOME="/tmp" gpg --no-default-keyring $GNUPG_PROXY_OPTION --keyring /etc/apt/keyrings/mozillateam.gpg --keyserver keyserver.ubuntu.com --recv-keys 0AB215679C571D1C8325275B9BDB3D89CE49EC21

cat <<EOF >> /etc/apt/sources.list
deb [signed-by=/etc/apt/keyrings/mozillateam.gpg] http://ppa.launchpad.net/mozillateam/ppa/ubuntu $UBUNTU_CODENAME main
EOF

# add PPA to apt preferences list, so PPA > snap
cat <<EOF >> /etc/apt/preferences.d/mozilla-firefox
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

# preparations for adding SBT (used for Chisel)
echo "[INFO] Adding Scala repo for SBT"
echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" > /etc/apt/sources.list.d/sbt.list
echo "deb https://repo.scala-sbt.org/scalasbt/debian /" > /etc/apt/sources.list.d/sbt_old.list
wget -qO- "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | gpg --dearmor > /tmp/scalasbt-release.gpg
install -D -o root -g root -m 644 /tmp/scalasbt-release.gpg /etc/apt/trusted.gpg.d/scalasbt-release.gpg
rm -f /tmp/scalasbt-release.gpg

apt-get update
apt-get install -y \
	dbus-x11 \
	firefox \
	gedit \
	htop \
	hub \
	jq \
	less \
	meld \
	nano \
	net-tools \
	nmap \
	parallel \
	qalculate-gtk \
	sbt \
	sudo \
	tigervnc-common \
	tigervnc-standalone-server \
	tigervnc-tools \
	tmux \
	vim \
	vim-gtk3 \
	websockify \
	xarchiver \
	xcvt \
	xdg-utils \
	xfce4 \
	xfce4-terminal \
	xterm

# need to switch Java-17 (for Chisel, as there is an incompatibility with java-21 and the scala version used by chisel)
update-java-alternatives --set "$(update-java-alternatives --list | grep 1.17 | cut -d' ' -f1)"

# remove light-locker and other power management stuff, otherwise VNC session locks up
apt-get purge -y light-locker pm-utils *screensaver*

# gnome-terminal is never requested here; it is only dragged in as an `x-terminal-emulator`
# alternative for xorg/xinit. It is unreliable in this container (the D-Bus-activated
# factory often fails to map a window, which surfaces as the XFCE dialog "Failed to execute
# default Terminal Emulator / Input/output error"). xfce4-terminal and xterm both provide
# x-terminal-emulator, so that dependency stays satisfied without it.
apt-get purge -y gnome-terminal

apt-get autoremove -y

/bin/dbus-uuidgen > /etc/machine-id

# noVNC is installed from upstream rather than from the `novnc` apt package, which on
# noble is 1.3.0 (October 2021).
#
# Up to 1.5.0 the client tracks the pressed mouse buttons as incremental state: the mask
# it sends to the VNC server is OR-ed with the button on `mousedown` and cleared again on
# `mouseup`, and nothing ever re-synchronises it. A `mouseup` that never reaches the page
# therefore leaves the bit set and the X server keeps the button held down for good --
# not even a page reload clears it, and no later click does either, because the mask is
# only ever adjusted by the matching release. Releasing outside the browser window and
# having the release swallowed by a native context menu are both easy to hit with a
# right-button drag, which is exactly KLayout's zoom box. A button stuck down also breaks
# window handling: X keeps an implicit pointer grab until all buttons are released, so
# every later click goes to the window that was under the cursor when the button went
# down, and the window manager never gets to focus or raise anything else.
#
# Upstream fixed this in 1.6.0 by deriving the mask from `MouseEvent.buttons`, the
# browser's authoritative view, on every mouse event, so a lost release self-corrects.
# A native VNC viewer is unaffected either way -- it reads the real button state from the
# OS instead of reconstructing it from a lossy DOM event stream.
NOVNC_VERSION=1.7.0
echo "[INFO] Installing noVNC version $NOVNC_VERSION into $NO_VNC_HOME"
git clone --quiet --depth=1 -b "v${NOVNC_VERSION}" https://github.com/novnc/noVNC.git /tmp/novnc
rm -rf "$NO_VNC_HOME"
mkdir -p "$NO_VNC_HOME"
# Only what the web client and `novnc_proxy` actually need; the documentation, test suite,
# translation sources and packaging metadata stay out of the image. websockify keeps coming
# from apt, wrapped further below.
cp -a /tmp/novnc/app /tmp/novnc/core /tmp/novnc/vendor /tmp/novnc/utils \
      /tmp/novnc/vnc.html /tmp/novnc/vnc_lite.html \
      /tmp/novnc/defaults.json /tmp/novnc/mandatory.json \
      /tmp/novnc/LICENSE.txt /tmp/novnc/AUTHORS "$NO_VNC_HOME"/
rm -rf /tmp/novnc

# `defaults.json` seeds a setting the user can still change -- and whose explicit choice
# noVNC then persists in localStorage, so it survives the next load.
#
# `resize=remote` makes the container desktop follow the browser window; the "Scaling
# Mode" setting overrides it. `autoconnect` keeps the documented short URL
# `http://<host>:<port>/?password=<pw>` connecting straight through: the client ignores
# `password` unless it is also told to connect, and would otherwise stop at its connect
# screen.
cat > "$NO_VNC_HOME"/defaults.json <<'EOF'
{
    "resize": "remote",
    "autoconnect": true
}
EOF

# `mandatory.json` pins a value and greys the control out. With an empty `host` the client
# derives the WebSocket URL from the address it was loaded from, which is always right
# here: the page is served by the very `websockify` that proxies the VNC session, so there
# is no reason to ever point it elsewhere. Left changeable, a host/port stored from an
# earlier session (e.g. from before `WEBSERVER_PORT` was changed) would win over the port
# actually in use.
cat > "$NO_VNC_HOME"/mandatory.json <<'EOF'
{
    "host": "",
    "port": ""
}
EOF

# websockify doubles as the web server for the client, and its request handler derives from
# Python's SimpleHTTPRequestHandler, which sends `Last-Modified` but no `Cache-Control`.
# Browsers then fall back to heuristic freshness -- roughly a tenth of the age of the file --
# and the client is served from cache without ever asking the server. The apt package's files
# carried their 2021 upstream mtimes, so a browser that had opened the session once kept
# running that copy for months across image upgrades. `no-cache` means "revalidate before
# use", not "do not store", so the cost is one conditional request per file, answered with a
# 304, on a connection that is usually localhost.
#
# `novnc_proxy` resolves websockify through `type -P`, so a wrapper earlier in PATH is picked
# up without patching either package. The wrapper drives the library directly, so it cannot
# recurse into itself.
#
# The missing headers are tracked upstream as https://github.com/novnc/websockify/issues/626;
# drop this wrapper once websockify sends `Cache-Control` itself.
cat > /usr/local/bin/websockify <<'EOF'
#!/usr/bin/python3
"""websockify, with Cache-Control: no-cache added to every response.

See 80_install_apps.sh for why: without it, browsers serve a stale noVNC client out of
their cache for a long time after the image is upgraded.
"""

import os
import sys

STOCK_WEBSOCKIFY = "/usr/bin/websockify"

try:
    from websockify.websockifyserver import WebSockifyRequestHandler
    from websockify.websocketproxy import websockify_init
except ImportError:
    # Upstream moved something; better a correctly working server with stale caching
    # than no web server at all.
    sys.stderr.write("[WARNING] cannot patch websockify caching, falling back to stock\n")
    os.execv(STOCK_WEBSOCKIFY, [STOCK_WEBSOCKIFY] + sys.argv[1:])

_end_headers = WebSockifyRequestHandler.end_headers


def end_headers(self):
    self.send_header("Cache-Control", "no-cache")
    _end_headers(self)


WebSockifyRequestHandler.end_headers = end_headers

sys.exit(websockify_init())
EOF
chmod 755 /usr/local/bin/websockify

# noVNC ships two clients: the stripped-down `vnc_lite.html` demo page (no control bar,
# hence no clipboard, no fullscreen, no scaling mode) and the full `vnc.html`. Serve the
# full one from `/`, via a redirect rather than a symlink, so that the query string of the
# short URL above is carried over to it.
cat > "$NO_VNC_HOME"/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>IIC-OSIC-TOOLS</title>
<script type="text/javascript">
    window.location.replace("vnc.html" + window.location.search + window.location.hash);
</script>
</head>
<body>
<p><a href="vnc.html">Continue to the noVNC client</a></p>
</body>
</html>
EOF

# clean up afterwards
echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
apt-get -y clean
rm -rf /var/lib/apt/lists/*
