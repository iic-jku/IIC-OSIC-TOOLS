#!/bin/bash
set -e

# Create symlinks for all installed tools
for binfile in "${TOOLS}"/*/bin/*; do
    linkname="${TOOLS}/bin/$(basename "$binfile")"
    # Skip if path contains "latest"
    if [[ "$binfile" == *latest* ]]; then
        continue
    fi
    if [ ! -e "$linkname" ]; then
        ln -s "$binfile" "$linkname"
    fi
done

# Create symlink for Xyce (lowercase)
ln -s "${TOOLS}"/bin/Xyce "${TOOLS}"/bin/xyce

# Install wrapper for Yosys so that modules are loaded automatically
# see https://github.com/iic-jku/IIC-OSIC-TOOLS/issues/43
rm -f "${TOOLS}"/bin/yosys
# shellcheck disable=SC2016
echo '#!/bin/bash
if [[ $1 == "-h" ]]; then
    exec -a "$0" "$TOOLS/yosys/bin/yosys" "$@"
else
    exec -a "$0" "$TOOLS/yosys/bin/yosys" -m ghdl -m slang "$@"
fi' > "${TOOLS}"/bin/yosys
chmod +x "${TOOLS}"/bin/yosys
