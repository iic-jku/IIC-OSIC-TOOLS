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
# need this WA because of https://github.com/IHP-GmbH/IHP-Open-PDK/issues/352
sed -i -E '/^(nature|discipline)/s/;( *$)//' psp103/discipline.h
sed -i -E '/^(nature|discipline)/s/;( *$)//' r3_cmc/discipline.h 
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
