#!/bin/bash
set -e

export SCRIPT_DIR=$TOOLS/osic-multitool

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

# Install ciel via pip
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	ciel

####################
# INSTALL SKY130 PDK
####################

echo "[INFO] Installing SKY130 PDK."
ciel enable "${OPEN_PDKS_REPO_COMMIT}" --pdk sky130

# Remove sky130B for size reasons
rm -rf "$PDK_ROOT"/ciel/sky130/versions/*/sky130B
rm -rf "$PDK_ROOT"/sky130B

if [ -d "$PDK_ROOT/sky130A" ]; then
	#FIXME gzip Liberty (.lib) files
	#FIXME cd "$PDK_ROOT/sky130A/libs.ref"
	#FIXME find . -name "*.lib" -exec gzip {} \;

	# Create compact model files
    cd "$PDK_ROOT/sky130A/libs.tech/ngspice" || exit 1

	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice tt
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice ss
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice ff
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice sf
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice fs

	# Add custom bindkeys
    echo "# Custom bindkeys for DIC" 		        >> "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc"
    echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc"

	# FIXME: Repair klayout tech file
	sed -i 's/>sky130</>sky130A</g' "$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
	sed -i 's/sky130.lyp/sky130A.lyp/g' "$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
	sed -i '/<base-path>/c\ <base-path/>' "$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
	# shellcheck disable=SC2016
	sed -i '/<original-base-path>/c\ <original-base-path>$PDK_ROOT/$PDK/libs.tech/klayout</original-base-path>' "$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
fi

if [ -d "$PDK_ROOT/sky130B" ]; then
	#FIXME gzip Liberty (.lib) files
	#FIXME cd "$PDK_ROOT/sky130B/libs.ref"
	#FIXME find . -name "*.lib" -exec gzip {} \;

	# Create compact model files
	cd "$PDK_ROOT/sky130B/libs.tech/ngspice" || exit 1
	
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice tt
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice ss
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice ff
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice sf
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice fs

    echo "# Custom bindkeys for DIC" 		        >> "$PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc"
    echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc"

	sed -i 's/>sky130</>sky130B</g' "$PDK_ROOT/sky130B/libs.tech/klayout/tech/sky130B.lyt"
	sed -i 's/sky130.lyp/sky130B.lyp/g' "$PDK_ROOT/sky130B/libs.tech/klayout/tech/sky130B.lyt"
	sed -i '/<base-path>/c\ <base-path/>' "$PDK_ROOT/sky130B/libs.tech/klayout/tech/sky130B.lyt"
	# shellcheck disable=SC2016
	sed -i '/<original-base-path>/c\ <original-base-path>$PDK_ROOT/$PDK/libs.tech/klayout</original-base-path>' "$PDK_ROOT/sky130B/libs.tech/klayout/tech/sky130B.lyt"
fi

######################
# INSTALL GF180MCU PDK
######################

echo "[INFO] Installing GF180 PDK."
# FIXME: use common tag from Dockerfile.
ciel enable f2e289da6753f26157a308c492cf990fdcd4932d --pdk-family gf180mcu

# Remove gf180mcuA, gf180mcuB and gf180mcuC for size reasons
rm -rf "$PDK_ROOT"/ciel/gf180mcu/versions/*/gf180mcuA
rm -rf "$PDK_ROOT"/ciel/gf180mcu/versions/*/gf180mcuB
rm -rf "$PDK_ROOT"/ciel/gf180mcu/versions/*/gf180mcuC
rm -rf "$PDK_ROOT"/gf180mcuA
rm -rf "$PDK_ROOT"/gf180mcuB
rm -rf "$PDK_ROOT"/gf180mcuC

git clone https://github.com/martinjankoehler/globalfoundries-pdk-libs-gf180mcu_fd_pr.git --branch gdsfactory-v7-to-v9-port /tmp/glofo-mjk
git clone https://github.com/mabrains/globalfoundries-pdk-libs-gf180mcu_fd_pr.git /tmp/glofo-mabrains

if [ -d "$PDK_ROOT/gf180mcuD" ]; then
	#FIXME gzip Liberty (.lib) files
	#FIXME cd "$PDK_ROOT/gf180mcuD/libs.ref"
	#FIXME find . -name "*.lib" -exec gzip {} \;

	cd "$PDK_ROOT/gf180mcuD/libs.tech/ngspice" || exit 1
	
	# Setup empty .spiceinit (harmonize with SG13G2)
	touch .spiceinit

	# Remove testing folders to save space
	cd "$PDK_ROOT/gf180mcuD"
	find . -name "testing" -print0 | xargs -0 rm -rf

	# Fix test schematic relative paths
	sed -i 's/{test_/{tests\/test_/g' $PDK_ROOT/gf180mcuD/libs.tech/xschem/tests/0_top.sch

	# Fix missing PDK variant in path definitions for in xschemrc
	sed -i 's|set 180MCU_MODELS ${PDK_ROOT}/models/ngspice|set 180MCU_MODELS ${PDK_ROOT}/gf180mcuD/libs.tech/ngspice|' $PDK_ROOT/gf180mcuD/libs.tech/xschem/xschemrc

	# Replace pymacro with working pcells.
	rm -rf $PDK_ROOT/gf180mcuD/libs.tech/klayout/tech/pymacros
	cp -a /tmp/glofo-mjk/cells/klayout/pymacros $PDK_ROOT/gf180mcuD/libs.tech/klayout/tech/pymacros

	cp -r /tmp/glofo-mabrains/rules/klayout/macros/ $PDK_ROOT/gf180mcuD/libs.tech/klayout/
	chmod -R 777 $PDK_ROOT/gf180mcuD/libs.tech/klayout/macros
fi

rm -rf /tmp/glofo-mjk
rm -rf /tmp/glofo-mabrains
