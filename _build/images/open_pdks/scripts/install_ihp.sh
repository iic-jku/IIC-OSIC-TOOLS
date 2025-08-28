#!/bin/bash
set -e
cd /tmp || exit 1

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

# install IHP-SG13G2
PDK="ihp-sg13g2"

#FIXME don't do a shallow clone until we work on the dev branch
#git clone --depth=1 https://github.com/IHP-GmbH/IHP-Open-PDK.git ihp
git clone https://github.com/IHP-GmbH/IHP-Open-PDK.git ihp
cd ihp || exit 1
# for now uses branch "dev" to get the latest releases
git checkout dev
git submodule update --init --recursive

# now move to the proper location
if [ -d $PDK ]; then
	mv $PDK "$PDK_ROOT/$PDK"
fi

# store git hash of installed PDK version for reference
PDK_COMMIT=$(git ls-remote https://github.com/IHP-GmbH/IHP-Open-PDK.git | grep HEAD | cut -f 1)
echo "$PDK_COMMIT" > "${PDK_ROOT}/${PDK}/COMMIT"

# compile the additional Verilog-A models
cd "$PDK_ROOT/$PDK/libs.tech/verilog-a" || exit 1
# ngspice
export PATH="$TOOLS/openvaf/bin:$PATH"
sed -i 's/\bopenvaf\b/& --target_cpu generic/' openvaf-compile-va.sh
chmod +x openvaf-compile-va.sh
./openvaf-compile-va.sh
# xyce
export PATH="$TOOLS/xyce/bin:$PATH"
chmod +x adms-compile-va.sh
./adms-compile-va.sh
if [ ! -f ../xyce/plugins/Xyce_Plugin_PSP103_VA.so ] || [ ! -f ../xyce/plugins/Xyce_Plugin_r3_cmc.so ]; then
    echo "[ERROR] ADMS model compilation for Xyce failed!"
    exit 1
fi

# remove testing folders to save space
cd "$PDK_ROOT/$PDK"
find . -name "testing" -print0 | xargs -0 rm -rf

# remove mdm files from doc folder to save space
cd "$PDK_ROOT/$PDK/libs.doc"
find . -name "*.mdm" -print0 | xargs -0 rm -rf

# remove measurement folder to save space
rm -rf "$PDK_ROOT/$PDK/libs.doc/meas"

#FIXME gzip Liberty (.lib) files
#FIXME cd "$PDK_ROOT/$PDK/libs.ref"
#FIXME find . -name "*.lib" -exec gzip {} \;

# replace klayout pcells of ihpsg13g2 pdk to get an extra option for creating a guard ring
# only temporary solution
git clone -b test-pycells https://github.com/iic-jku/IHP-Open-PDK.git
rm -rf $PDK_ROOT/$PDK/libs.tech/klayout/python/sg13g2_pycell_lib
cp -rf IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/python/sg13g2_pycell_lib $PDK_ROOT/$PDK/libs.tech/klayout/python/
rm -rf IHP-Open-PDK
