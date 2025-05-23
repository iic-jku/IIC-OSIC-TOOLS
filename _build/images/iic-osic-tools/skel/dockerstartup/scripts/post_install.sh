#!/bin/bash

# shellcheck disable=SC1091

# cleanup of installation leftovers
[ -f /dependencies.sh ] && rm -f /dependencies.sh 
[ -f /install.sh ] && rm -f /install.sh

# move env.sh into place as .bashrc
mv "$STARTUPDIR/scripts/env.sh" "$HOME/.bashrc"

# create dirs if not yet existing
[ ! -d "$DESIGNS" ] && mkdir -p "$DESIGNS"
[ ! -d "$PDK_ROOT" ] && mkdir -p "$PDK_ROOT"
[ ! -d "$EXAMPLES" ] && mkdir -p "$EXAMPLES"

# link all tool binaries into one bin folder
mkdir -p "$TOOLS/bin"
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .
# Add link for xyce, as binary is named Xyce
ln -s Xyce xyce

# install wrapper for Yosys so that modules are loaded automatically
# see https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/43
cd "$TOOLS/bin" || exit
rm -f yosys
# shellcheck disable=SC2016
echo '#!/bin/bash
if [[ $1 == "-h" ]]; then
    exec -a "$0" "$TOOLS/yosys/bin/yosys" "$@"
else
    exec -a "$0" "$TOOLS/yosys/bin/yosys" -m ghdl -m slang "$@"
fi' > yosys
chmod +x yosys

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

# set access rights for home dir and designs dir
chown -R 1000:1000 "$HOME"
chmod -R +rw "$HOME"
chown -R 1000:1000 "$DESIGNS"

# set correct user permissions
"$STARTUPDIR/scripts/set_user_permission.sh" "$STARTUPDIR" "$HOME"
