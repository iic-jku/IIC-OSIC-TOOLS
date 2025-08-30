#!/bin/bash

# shellcheck disable=SC1091

# move env.sh into place as .bashrc
mv "$STARTUPDIR/scripts/env.sh" "$HOME/.bashrc"

# create dirs if not yet existing
mkdir -p "$DESIGNS"
mkdir -p "$PDK_ROOT"
mkdir -p "$EXAMPLES"

# folder for links to all tool binaries into one bin folder
mkdir -p "$TOOLS/bin"

# create dir for logs
mkdir "$STARTUPDIR"/logs

# For the WSLg VGPU to correctly work, the potentially mounted driver directory needs to be added to the dynamic linker config:
echo "/usr/lib/wsl/lib" > /etc/ld.so.conf.d/ld.wsl.conf
ldconfig

# set /usr/bin/python3 to provide "/usr/bin/python"
update-alternatives --set python /usr/bin/python3

# Update the mime-type and application database so typical IC-Design files are recognized
update-mime-database /usr/share/mime
update-desktop-database /usr/share/applications

# create default XDG_RUNTIME_DIR
# FIXME: Do not create an all-world readable directory, but one that fits the exact user of the container.
mkdir -p /tmp/runtime-default
chmod 777 /tmp/runtime-default

# Remove Ubuntu user in container to prevent conflicts with designer user.
userdel ubuntu

# set access rights for home dir and designs dir
chown -R 1000:1000 "$HOME"
chmod -R +rw "$HOME"
chown -R 1000:1000 "$DESIGNS"

# set correct user permissions
"$STARTUPDIR/scripts/set_user_permission.sh" "$STARTUPDIR" "$HOME"
