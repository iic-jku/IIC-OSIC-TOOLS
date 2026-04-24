# ========================================================================
# Chipathon default-PDK override
#
# This file is sourced by /etc/profile AFTER iic-osic-tools-setup.sh
# (alphabetical order in /etc/profile.d/) and re-applies all PDK-related
# environment variables consistent with `sak-pdk <pdk>`.
#
# To change the chipathon default PDK, edit CHIPATHON_DEFAULT_PDK below.
# Supported values: sky130A, sky130B, gf180mcuC, gf180mcuD,
#                   ihp-sg13g2, ihp-sg13cmos5l
# ========================================================================

CHIPATHON_DEFAULT_PDK="gf180mcuD"

# Honor a per-user override if set before login (e.g. via container env).
: "${PDK:=$CHIPATHON_DEFAULT_PDK}"

# Only act if the selected PDK actually exists in PDK_ROOT.
if [ -n "${PDK_ROOT:-}" ] && [ -d "$PDK_ROOT/$PDK" ]; then
    export PDK
    export PDKPATH="$PDK_ROOT/$PDK"
    export SPICE_USERINIT_DIR="$PDKPATH/libs.tech/ngspice"
    export KLAYOUT_PATH="/headless/.klayout:$PDKPATH/libs.tech/klayout:$PDKPATH/libs.tech/klayout/tech"

    case "$PDK" in
        sky130A|sky130B)        export STD_CELL_LIBRARY="sky130_fd_sc_hd" ;;
        ihp-sg13g2)             export STD_CELL_LIBRARY="sg13g2_stdcell" ;;
        ihp-sg13cmos5l)         export STD_CELL_LIBRARY="sg13cmos5l_stdcell" ;;
        gf180mcuC|gf180mcuD)    export STD_CELL_LIBRARY="gf180mcu_fd_sc_mcu7t5v0" ;;
    esac

    # gdsfactory venv selection for KLayout pcell libraries (mirrors sak-pdk).
    case "$PDK" in
        sky130A|sky130B)        _KLAYOUT_VENV="/foss/tools/klayout_gdsfactory8" ;;
        gf180mcuC|gf180mcuD)    _KLAYOUT_VENV="/foss/tools/klayout_gdsfactory9" ;;
        *)                      _KLAYOUT_VENV="" ;;
    esac
    if [ -n "$_KLAYOUT_VENV" ] && [ -x "$_KLAYOUT_VENV/bin/python3" ]; then
        KLAYOUT_PYTHONPATH=$("$_KLAYOUT_VENV/bin/python3" -c 'import site; print(site.getsitepackages()[0])')
        export KLAYOUT_PYTHONPATH
    else
        unset KLAYOUT_PYTHONPATH
    fi
    unset _KLAYOUT_VENV
fi

unset CHIPATHON_DEFAULT_PDK
