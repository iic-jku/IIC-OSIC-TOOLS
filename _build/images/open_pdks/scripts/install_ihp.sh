#!/bin/bash
set -e
: "${TOOLS:?TOOLS is not set}"
: "${PDK_ROOT:?PDK_ROOT is not set}"
export SCRIPT_DIR=$TOOLS/osic-multitool
cd /tmp || exit 1

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

# Install IHP-SG13G2
PDK="ihp-sg13g2"

#FIXME don't do a shallow clone while we work on the dev branch
#git clone --depth=1 https://github.com/IHP-GmbH/IHP-Open-PDK.git ihp
git clone https://github.com/iic-jku/IHP-Open-PDK.git ihp
cd ihp || exit 1
# For now uses branch "dev" to get the latest releases
git checkout dev
git submodule update --init --recursive

# Clone IHP-SG13CMOS5L inside the IHP-Open-PDK directory (before moving sg13g2,
# so that symlinks in sg13cmos5l that point to sg13g2 files are valid)
git clone https://github.com/IHP-GmbH/ihp-sg13cmos5l.git

# Store git hash of installed PDK version for reference (before moving)
PDK_COMMIT=$(git -C /tmp/ihp rev-parse HEAD)

# now move sg13g2 to the proper location
if [ -d "/tmp/ihp/$PDK" ]; then
	mv "/tmp/ihp/$PDK" "$PDK_ROOT/$PDK"
fi

echo "$PDK_COMMIT" > "${PDK_ROOT}/${PDK}/COMMIT"

# Compile the additional Verilog-A models
cd "$PDK_ROOT/$PDK/libs.tech/verilog-a" || exit 1
# ngspice
export PATH="$TOOLS/openvaf/bin:$PATH"
chmod +x openvaf-compile-va.sh
./openvaf-compile-va.sh --compile-model-generic
# Xyce
export PATH="$TOOLS/xyce/bin:$PATH"
chmod +x adms-compile-va.sh
./adms-compile-va.sh
if [ ! -f ../xyce/plugins/Xyce_Plugin_PSP103_VA.so ] || [ ! -f ../xyce/plugins/Xyce_Plugin_r3_cmc.so ]; then
    echo "[ERROR] ADMS model compilation for Xyce failed!"
    exit 1
fi

# Add custom bindkeys for Magic
echo "# Custom bindkeys for ICD" 		        >> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"
echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"

# Remove testing folders to save space
cd "$PDK_ROOT/$PDK"
find . -name "testing" -type d -print0 | xargs -0 rm -rf

# Remove mdm files from doc folder to save space
cd "$PDK_ROOT/$PDK/libs.doc"
find . -name "*.mdm" -print0 | xargs -0 rm -f

# Remove measurement folder to save space
rm -rf "$PDK_ROOT/$PDK/libs.doc/meas"

#FIXME gzip Liberty (.lib) files
#FIXME cd "$PDK_ROOT/$PDK/libs.ref"
#FIXME find . -name "*.lib" -exec gzip {} \;

# Install IHP-SG13CMOS5L
PDK="ihp-sg13cmos5l"

# Move sg13cmos5l to the proper location
if [ -d "/tmp/ihp/$PDK" ]; then
	mv "/tmp/ihp/$PDK" "$PDK_ROOT/$PDK"
fi

# Store git hash of installed PDK version for reference
PDK_COMMIT=$(git -C "$PDK_ROOT/$PDK" rev-parse HEAD)
echo "$PDK_COMMIT" > "${PDK_ROOT}/${PDK}/COMMIT"

# Copy compiled OSDI models and Xyce plugins from sg13g2 (sg13cmos5l uses the same models)
cp "$PDK_ROOT/ihp-sg13g2/libs.tech/ngspice/osdi/"*.osdi "$PDK_ROOT/$PDK/libs.tech/ngspice/osdi/"
cp "$PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/"*.so "$PDK_ROOT/$PDK/libs.tech/xyce/plugins/"

# Add custom bindkeys for Magic
echo "# Custom bindkeys for ICD" 		        >> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"
echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc"

# Remove testing folders to save space
cd "$PDK_ROOT/$PDK"
find . -name "testing" -type d -print0 | xargs -0 rm -rf

# Cleanup cloned repository
rm -rf /tmp/ihp
