#!/bin/bash
# klayout_install_packages.sh
#
# Based on the script from LuighiV's iic-osic-tools-project-template
# https://github.com/LuighiV/iic-osic-tools-project-template/blob/main/designs/scripts/klayout_install_packages.sh
#
# Based on script tool_configuration.sh
# https://github.com/unic-cass/uniccass-icdesign-tools
# 
# Usage: ./klayout_install_packages.sh
# KLAYOUT_HOME must be set in the environment
# by default is /headless/.klayout
#

if [[ -z $KLAYOUT_HOME ]]; then
    KLAYOUT_HOME=/headless/.klayout
fi

KLAYOUT_SALT=$KLAYOUT_HOME/salt
KLAYOUT_BIN=$(command -v klayout)
if [[ -z $KLAYOUT_BIN ]]; then
    if [[ -x "$TOOLS/klayout/klayout" ]]; then
        KLAYOUT_BIN="$TOOLS/klayout/klayout"
    else
        echo "ERROR: klayout binary not found (not on PATH and not at \$TOOLS/klayout/klayout)" >&2
        exit 1
    fi
fi

mkdir -p $KLAYOUT_SALT

packages=(
klive
gdsfactory
xsection
)


for package in "${packages[@]}"; do

    COUNTER=15
    if [[ ! -d "$KLAYOUT_SALT/$package" ]]; then
        "$KLAYOUT_BIN" -t -ne -rr -b -y $package
    fi

    until [[ "$?" == "0" || $COUNTER -lt 0 ]]
    do
        sleep 1
        ((COUNTER--))
        if [[ ! -d "$KLAYOUT_SALT/$package" ]]; then
            "$KLAYOUT_BIN" -t -ne -rr -b -y $package
        fi
    done

    if [[ "$COUNTER" == "0" ]]; then
        exit 1
    fi
done
