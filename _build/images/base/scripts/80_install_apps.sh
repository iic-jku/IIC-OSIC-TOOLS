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
	novnc \
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

# noVNC ships two clients: the stripped-down `vnc_lite.html` demo page (no control
# bar, hence no clipboard, no fullscreen, no scaling mode) and the full `vnc.html`.
# Serve the full one from `/`, via a redirect rather than a symlink, so that the
# short URL `http://<host>:<port>/?password=<pw>` keeps working: `vnc.html` ignores
# `password` unless `autoconnect` is set too, and would otherwise stop at its
# connect screen.
#
# `host`/`port` are pinned from the current location on every load. The full client
# persists its settings in localStorage and prefers a stored value over its built-in
# default, so a port left over from an earlier session (e.g. after changing
# WEBSERVER_PORT) would otherwise win over the port actually in use.
#
# `resize=remote` (the desktop follows the browser window) is only injected while the
# user has no stored preference; noVNC writes that key only when "Scaling Mode" is
# changed in the settings panel, so an explicit choice there persists and is not
# overridden on the next load.
rm -f "$NO_VNC_HOME"/index.html
cat > "$NO_VNC_HOME"/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>IIC-OSIC-TOOLS</title>
<script type="text/javascript">
    (function () {
        "use strict";
        var params = new URLSearchParams(window.location.search);
        params.set("host", window.location.hostname);
        params.set("port", window.location.port ||
                           (window.location.protocol === "https:" ? "443" : "80"));
        if (!params.has("autoconnect")) {
            params.set("autoconnect", "1");
        }
        if (!params.has("resize")) {
            var stored = null;
            try {
                stored = window.localStorage.getItem("resize");
            } catch (e) {
                /* storage blocked by the browser, fall back to the default */
            }
            if (stored === null) {
                params.set("resize", "remote");
            }
        }
        window.location.replace("vnc.html?" + params.toString() + window.location.hash);
    })();
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
