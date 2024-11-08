#!/bin/bash
set -e
set -u

#UBUNTU_VERSION=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release | sed 's/"//g')
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

# Add PPA to apt preferences list, so PPA > snap
cat <<EOF >> /etc/apt/preferences.d/mozilla-firefox
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

# Preparations for adding VS Code
echo "[INFO] Adding Microsoft Repo for VS Code"
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

cat <<EOF >> /etc/apt/sources.list.d/vscode.list
deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF

rm -f packages.microsoft.gpg

apt update
apt install -y \
        code \
        firefox \
        gedit \
        gnuplot \
        htop \
        hub \
        jq \
        meld \
        nano \
        net-tools \
        nmap \
        novnc \
        openems \
        parallel \
        sudo \
        tigervnc-standalone-server \
        vim \
        vim-gtk3 \
        websockify \
        xarchiver \
        xfce4 \
        xfce4-terminal \
        xterm

# Remove light-locker and other power management stuff, otherwise VNC session locks up
apt purge -y light-locker pm-utils *screensaver*
apt autoremove -y

# FIXME rm /etc/xdg/autostart/polkit*
/bin/dbus-uuidgen > /etc/machine-id

## create index.html to forward automatically to `vnc_lite.html`
ln -s "$NO_VNC_HOME"/vnc_lite.html "$NO_VNC_HOME"/index.html


#clean up afterwards
rm -rf /tmp/*
