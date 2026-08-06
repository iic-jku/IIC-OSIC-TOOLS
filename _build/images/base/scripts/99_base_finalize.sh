#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
# shellcheck disable=SC1091

set -e

# Create dirs if not yet existing
mkdir -p "$DESIGNS"
mkdir -p "$PDK_ROOT"
mkdir -p "$EXAMPLES"

# Folder for links to all tool binaries into one bin folder
mkdir -p "$TOOLS/bin"

# Create dir for logs
mkdir -p "$STARTUPDIR"/logs

# For the WSLg VGPU to correctly work, the potentially mounted driver directory needs to be added to the dynamic linker config:
echo "/usr/lib/wsl/lib" > /etc/ld.so.conf.d/ld.wsl.conf
ldconfig

# Set /usr/bin/python3 to provide "/usr/bin/python"
update-alternatives --set python /usr/bin/python3

# Update the mime-type and application database so typical IC-Design files are recognized
update-mime-database /usr/share/mime
update-desktop-database /usr/share/applications

# Create default XDG_RUNTIME_DIR
# FIXME: Do not create an all-world readable directory, but one that fits the exact user of the container.
mkdir -p /tmp/runtime-default
chmod 777 /tmp/runtime-default

# Remove Ubuntu user in container to prevent conflicts with designer user
userdel ubuntu

# Trim XFCE session daemons that are useless inside a container: the udisks2
# GVfs volume monitor (there is no udisks daemon/system D-Bus in the
# container) and the tumbler thumbnailer. Removing the GVfs/D-Bus activation
# files keeps Thunar & friends from spawning them.
rm -f /usr/share/gvfs/remote-volume-monitors/udisks2.monitor \
      /usr/share/dbus-1/services/org.gtk.vfs.UDisks2VolumeMonitor.service \
      /usr/share/dbus-1/services/org.xfce.Tumbler.Cache1.service \
      /usr/share/dbus-1/services/org.xfce.Tumbler.Manager1.service \
      /usr/share/dbus-1/services/org.xfce.Tumbler.Thumbnailer1.service

# Remove Rust toolchains/caches that rustup auto-downloads when pip has to
# build a package from source (no prebuilt wheel, e.g. on aarch64); a
# toolchain is re-downloaded on first cargo use if a user needs Rust
rm -rf "$HOME/.rustup" "$HOME/.cargo"

# Set access rights for home dir and designs dir
chown -R 1000:1000 "$HOME"
chmod -R +rw "$HOME"
chown -R 1000:1000 "$DESIGNS"

# Set correct user permissions
"$STARTUPDIR/scripts/set_user_permission.sh" "$STARTUPDIR" "$HOME"
