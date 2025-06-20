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

# remove gf180mcuA, gf180mcuB and gf180mcuC for size reasons
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
	
	# setup empty .spiceinit (harmonize with SG13G2)
	touch .spiceinit

	# remove testing folders to save space
	cd "$PDK_ROOT/gf180mcuD"
	find . -name "testing" -print0 | xargs -0 rm -rf

	# fix test schematic relative paths
	sed -i 's/{test_/{tests\/test_/g' $PDK_ROOT/gf180mcuD/libs.tech/xschem/tests/0_top.sch

	# fix missing PDK variant in path definitions for in xschemrc
	sed -i 's|set 180MCU_MODELS ${PDK_ROOT}/models/ngspice|set 180MCU_MODELS ${PDK_ROOT}/gf180mcuD/libs.tech/ngspice|' $PDK_ROOT/gf180mcuD/libs.tech/xschem/xschemrc

	# Replace pymacro with working pcells.
	rm -rf $PDK_ROOT/gf180mcuD/libs.tech/klayout/tech/pymacros
	cp -a /tmp/glofo-mjk/cells/klayout/pymacros $PDK_ROOT/gf180mcuD/libs.tech/klayout/tech/pymacros

	cp -r /tmp/glofo-mabrains/rules/klayout/macros/ $PDK_ROOT/gf180mcuD/libs.tech/klayout/
	chmod -R 777 $PDK_ROOT/gf180mcuD/libs.tech/klayout/macros
fi

rm -rf /tmp/glofo-mjk
rm -rf /tmp/glofo-mabrains
