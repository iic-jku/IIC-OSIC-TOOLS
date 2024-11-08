#!/bin/bash
set -e

export SCRIPT_DIR=$TOOLS/osic-multitool

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

####################
# INSTALL SKY130 PDK
####################

echo "[INFO] Installing SKY130 PDK."
volare enable "${OPEN_PDKS_REPO_COMMIT}" --pdk sky130

rm -rf "$PDK_ROOT"/volare/sky130/versions/*/sky130B
rm -rf "$PDK_ROOT"/sky130B

if [ -d "$PDK_ROOT/sky130A" ]; then

    cd "$PDK_ROOT/sky130A/libs.tech/ngspice" || exit 1

	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice tt
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice ss
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice ff
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice sf
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice fs

    echo "# Custom bindkeys for IIC" 		        >> "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc"
    echo "source $SCRIPT_DIR/iic-magic-bindkeys" 	>> "$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc"

	# FIXME: Repair klayout tech file
	sed -i 's/>sky130</>sky130A</g' "$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
	sed -i 's/sky130.lyp/sky130A.lyp/g' "$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
	sed -i '/<base-path>/c\ <base-path/>' "$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
	# shellcheck disable=SC2016
	sed -i '/<original-base-path>/c\ <original-base-path>$PDK_ROOT/$PDK/libs.tech/klayout</original-base-path>' "$PDK_ROOT/sky130A/libs.tech/klayout/tech/sky130A.lyt"
fi

if [ -d "$PDK_ROOT/sky130B" ]; then

	cd "$PDK_ROOT/sky130B/libs.tech/ngspice" || exit 1
	
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice tt
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice ss
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice ff
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice sf
	"$SCRIPT_DIR/iic-spice-model-red.py" sky130.lib.spice fs

    echo "# Custom bindkeys for IIC" 		        >> "$PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc"
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
volare enable "${OPEN_PDKS_REPO_COMMIT}" --pdk gf180mcu

#FIXME maybe need to run spice model file reduction here as well
#FIXME need to define a magic bindkeys for gf180mcu

rm -rf "$PDK_ROOT"/volare/gf180mcu/versions/*/gf180mcuA
rm -rf "$PDK_ROOT"/volare/gf180mcu/versions/*/gf180mcuB
rm -rf "$PDK_ROOT"/gf180mcuA
rm -rf "$PDK_ROOT"/gf180mcuB

if [ -d "$PDK_ROOT/gf180mcuC" ]; then
	cd "$PDK_ROOT/gf180mcuC/libs.tech/ngspice" || exit 1
	
	# Setup empty .spiceinit (harmonize with SG13G2)
	touch .spiceinit
fi

if [ -d "$PDK_ROOT/gf180mcuD" ]; then
	cd "$PDK_ROOT/gf180mcuD/libs.tech/ngspice" || exit 1
	
	# Setup empty .spiceinit (harmonize with SG13G2)
	touch .spiceinit
fi
