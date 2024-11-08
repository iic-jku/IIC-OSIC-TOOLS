#!/bin/bash

# shellcheck disable=SC1091

# Cleanup of installation leftovers
# ---------------------------------
[ -f /dependencies.sh ] && rm -f /dependencies.sh 
[ -f /install.sh ] && rm -f /install.sh

# Move env.sh into place as .bashrc
# ---------------------------------
mv "$STARTUPDIR/scripts/env.sh" "$HOME/.bashrc"

# Create dirs if not yet existing
# -------------------------------
[ ! -d "$DESIGNS" ] && mkdir -p "$DESIGNS"
[ ! -d "$PDK_ROOT" ] && mkdir -p "$PDK_ROOT"
[ ! -d "$EXAMPLES" ] && mkdir -p "$EXAMPLES"

# Install the SPEF extractor
# --------------------------
cp -a "$TOOLS/sak/openlane/spef_extractor" "$TOOLS/"

# Link all tool binaries into one bin folder
# ------------------------------------------
mkdir -p "$TOOLS/bin"
cd "$TOOLS/bin" || exit
ln -s ../*/bin/* .
# Add link for xyce, as binary is named Xyce
ln -s Xyce xyce

# Install wrapper for Yosys so that modules are loaded automatically
# See https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/43
# ------------------------------------------------------------------
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

# FIXME Not sure what this does whether it is even needed
# -------------------------------------------------------
ln -s "$TOOLS"/xschem/* "$TOOLS"/xschem/

# Create dir for logs
# -------------------
mkdir "$STARTUPDIR"/logs

# Set /usr/bin/python3 to provide "/usr/bin/python"
# -------------------------------------------------
update-alternatives --set python /usr/bin/python3

# Set access rights for home dir and designs dir
# ----------------------------------------------
chown -R 1000:1000 "$HOME"
chmod -R +rw "$HOME"
chown -R 1000:1000 "$DESIGNS"

# Set correct user permissions
# ----------------------------
"$STARTUPDIR/scripts/set_user_permission.sh" "$STARTUPDIR" "$HOME"
