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
	openjdk-17-jdk \
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
apt-get autoremove -y

/bin/dbus-uuidgen > /etc/machine-id

# create index.html to forward automatically to `vnc_lite.html`
ln -s "$NO_VNC_HOME"/vnc_lite.html "$NO_VNC_HOME"/index.html

# clean up afterwards
echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
apt-get -y clean
rm -rf /var/lib/apt/lists/*
