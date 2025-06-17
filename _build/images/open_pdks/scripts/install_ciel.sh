#!/bin/bash
set -e

export SCRIPT_DIR=$TOOLS/osic-multitool

if [ ! -d "$PDK_ROOT" ]; then
    mkdir -p "$PDK_ROOT"
fi

######################
# INSTALL GF180MCU PDK
######################

echo "[INFO] Installing GF180 PDK."
# FIXME: use common tag from Dockerfile.
ciel enable f2e289da6753f26157a308c492cf990fdcd4932d --pdk-family gf180mcu

# remove gf180mcuA and gf180mcuB for size reasons
rm -rf "$PDK_ROOT"/ciel/gf180mcu/versions/*/gf180mcuA
rm -rf "$PDK_ROOT"/ciel/gf180mcu/versions/*/gf180mcuB
rm -rf "$PDK_ROOT"/gf180mcuA
rm -rf "$PDK_ROOT"/gf180mcuB

if [ -d "$PDK_ROOT/gf180mcuC" ]; then
	#FIXME gzip Liberty (.lib) files
	#FIXME cd "$PDK_ROOT/gf180mcuC/libs.ref"
	#FIXME find . -name "*.lib" -exec gzip {} \;

	cd "$PDK_ROOT/gf180mcuC/libs.tech/ngspice" || exit 1
	
	# setup empty .spiceinit (harmonize with SG13G2)
	touch .spiceinit

	# remove testing folders to save space
	cd "$PDK_ROOT/gf180mcuC"
	find . -name "testing" -print0 | xargs -0 rm -rf

	# fix test schematic relative paths
	sed -i 's/{test_/{tests\/test_/g' $PDK_ROOT/gf180mcuC/libs.tech/xschem/tests/0_top.sch

	# fix missing PDK variant in path definitions for in xschemrc
	sed -i 's|set 180MCU_MODELS ${PDK_ROOT}/models/ngspice|set 180MCU_MODELS ${PDK_ROOT}/gf180mcuC/models/ngspice|' $PDK_ROOT/gf180mcuC/libs.tech/xschem/xschemrc

	# Replace pymacro with working pcells.
        git clone https://github.com/martinjankoehler/globalfoundries-pdk-libs-gf180mcu_fd_pr.git --branch gdsfactory-v7-to-v9-port /tmp/glofo-mjk
        rm -rf /foss/pdks/ciel/gf180mcu/versions/f2e289da6753f26157a308c492cf990fdcd4932d/gf180mcuC/libs.tech/klayout/tech/pymacros
        cp -a /tmp/glofo-mjk/cells/klayout/pymacros /foss/pdks/ciel/gf180mcu/versions/f2e289da6753f26157a308c492cf990fdcd4932d/gf180mcuC/libs.tech/klayout/tech/pymacros
        rm -rf /tmp/glofo-mjk


fi

if [ -d "$PDK_ROOT/gf180mcuD" ]; then
	#FIXME gzip Liberty (.lib) files
	#FIXME cd "$PDK_ROOT/gf180mcuD/libs.ref"
	#FIXME find . -name "*.lib" -exec gzip {} \;

	cd "$PDK_ROOT/gf180mcuD/libs.tech/ngspice" || exit 1
	
	# setup empty .spiceinit (harmonize with SG13G2)
	touch .spiceinit

	# remove testing folders to save space
	cd "$PDK_ROOT/gf180mcuD"
	find . -name "testing" -print0 | xargs -0 rm -rf

	# fix test schematic relative paths
	sed -i 's/{test_/{tests\/test_/g' $PDK_ROOT/gf180mcuD/libs.tech/xschem/tests/0_top.sch

	# fix missing PDK variant in path definitions for in xschemrc
	sed -i 's|set 180MCU_MODELS ${PDK_ROOT}/models/ngspice|set 180MCU_MODELS ${PDK_ROOT}/gf180mcuD/models/ngspice|' $PDK_ROOT/gf180mcuD/libs.tech/xschem/xschemrc

	# Replace pymacro with working pcells.
	git clone https://github.com/martinjankoehler/globalfoundries-pdk-libs-gf180mcu_fd_pr.git --branch gdsfactory-v7-to-v9-port /tmp/glofo-mjk
	rm -rf /foss/pdks/ciel/gf180mcu/versions/f2e289da6753f26157a308c492cf990fdcd4932d/gf180mcuD/libs.tech/klayout/tech/pymacros
	cp -a /tmp/glofo-mjk/cells/klayout/pymacros /foss/pdks/ciel/gf180mcu/versions/f2e289da6753f26157a308c492cf990fdcd4932d/gf180mcuD/libs.tech/klayout/tech/pymacros
	rm -rf /tmp/glofo-mjk
fi
