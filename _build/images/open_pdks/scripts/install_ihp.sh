#!/bin/bash
set -e
set -o pipefail
export SCRIPT_DIR=$TOOLS/osic-multitool
cd /tmp || exit 1

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

# Install IHP-SG13G2
PDK="ihp-sg13g2"
IHP_REPO_URL="https://github.com/iic-jku/IHP-Open-PDK.git"

echo "[INFO] Installing IHP SG13G2 PDK."
git clone "$IHP_REPO_URL" ihp
cd ihp || exit 1
# For now uses branch "dev" to get the latest releases
git checkout dev
git submodule update --init --recursive

# Now move to the proper location
if [ -d "$PDK" ]; then
	mv "$PDK" "$PDK_ROOT/$PDK"
else
	echo "[ERROR] PDK directory '$PDK' not found after clone!"
	exit 1
fi

# Store git hash of installed PDK version for reference
PDK_COMMIT=$(git rev-parse HEAD)
echo "$PDK_COMMIT" > "${PDK_ROOT}/${PDK}/COMMIT"

# Cleanup cloned repo to save space
cd /tmp || exit 1
rm -rf ihp

# Compile the additional Verilog-A models
echo "[INFO] Compiling Verilog-A models."
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
echo "[INFO] Removing unnecessary files to save space."
cd "$PDK_ROOT/$PDK"
find . -name "testing" -print0 | xargs -0 rm -rf

# Remove mdm files from doc folder to save space
cd "$PDK_ROOT/$PDK/libs.doc"
find . -name "*.mdm" -print0 | xargs -0 rm -rf

# Remove measurement folder to save space
rm -rf "$PDK_ROOT/$PDK/libs.doc/meas"

#FIXME gzip Liberty (.lib) files
#FIXME cd "$PDK_ROOT/$PDK/libs.ref"
#FIXME find . -name "*.lib" -exec gzip {} \;

# Perform required preparation of IHP PDK for use with VACASK
echo "[INFO] Preparing IHP PDK for VACASK."
cd /tmp || exit 1
git clone https://codeberg.org/arpadbuermen/VACASK.git
OPENVAF_DIR=${TOOLS}/openvaf/bin PYTHONPATH=/tmp/VACASK/python \
    python3 -m sg13g2tovc
cp /tmp/VACASK/demo/ihp-sg13g2/.vacaskrc.toml "$PDK_ROOT/$PDK/libs.tech/vacask/.vacaskrc.toml"
rm -rf VACASK

# Remove *.orig files created during PDK preparation
#FIXME find "$PDK_ROOT/$PDK" -name "*.orig" -delete

echo "[INFO] IHP SG13G2 PDK installation complete."
