#!/bin/sh
# ========================================================================
# chipathon: patch the base image's hardcoded default PDK
#
# The base image hardcodes PDK=ihp-sg13g2 in TWO files, both read at every
# shell startup:
#   1. /headless/.bashrc                       (non-login shells:
#      xfce4-terminal, VNC shells, sourced explicitly by ui_startup.sh)
#   2. /etc/profile.d/iic-osic-tools-setup.sh  (login shells: SSH,
#      docker exec -l, jupyter-spawned shells)
#
# This script patches the hardcoded `export PDK=` / `export
# STD_CELL_LIBRARY=` lines in-place (derived variables PDKPATH,
# SPICE_USERINIT_DIR, KLAYOUT_PATH reference $PDK and stay consistent
# with sak-pdk for free), and appends a trailing block that sets
# KLAYOUT_PYTHONPATH from the current $PDK — mirroring the logic in
# sak-pdk-script.sh. The block runs AFTER $DESIGNS/.designinit, so user
# overrides (e.g. `sak-pdk sky130A` in .designinit) keep working.
#
# Usage: patch-pdk.sh <PDK> <STD_CELL_LIBRARY>
# ========================================================================
set -eu

PDK_DEFAULT="${1:?missing PDK arg}"
STDCELL_DEFAULT="${2:?missing STD_CELL_LIBRARY arg}"

MARKER='chipathon: KLAYOUT_PYTHONPATH parity'

TAIL=$(cat <<'EOF'

# --- chipathon: KLAYOUT_PYTHONPATH parity with sak-pdk (per current $PDK) ---
case "${PDK:-}" in
    sky130A|sky130B)         _chipathon_klayout_venv=/foss/tools/klayout_gdsfactory8 ;;
    gf180mcuC|gf180mcuD)     _chipathon_klayout_venv=/foss/tools/klayout_gdsfactory9 ;;
    *)                       _chipathon_klayout_venv="" ;;
esac
if [ -n "$_chipathon_klayout_venv" ] && [ -x "$_chipathon_klayout_venv/bin/python3" ]; then
    KLAYOUT_PYTHONPATH=$("$_chipathon_klayout_venv/bin/python3" -c 'import site; print(site.getsitepackages()[0])') && export KLAYOUT_PYTHONPATH
fi
unset _chipathon_klayout_venv
EOF
)

for f in /headless/.bashrc /etc/profile.d/iic-osic-tools-setup.sh; do
    if [ ! -f "$f" ]; then
        echo "ERROR: $f missing in base image" >&2
        exit 1
    fi
    if ! grep -q '^export PDK=' "$f"; then
        echo "ERROR: no 'export PDK=' line in $f" >&2
        exit 1
    fi
    if ! grep -q '^export STD_CELL_LIBRARY=' "$f"; then
        echo "ERROR: no 'export STD_CELL_LIBRARY=' line in $f" >&2
        exit 1
    fi

    # Idempotent: skip if already patched.
    if grep -q "$MARKER" "$f"; then
        echo "--- $f already patched, skipping ---"
        continue
    fi

    sed -i "s|^export PDK=.*|export PDK=${PDK_DEFAULT}|" "$f"
    sed -i "s|^export STD_CELL_LIBRARY=.*|export STD_CELL_LIBRARY=${STDCELL_DEFAULT}|" "$f"
    sed -i 's|:\$PDKPATH/libs\.tech/klayout/tech||g' "$f"
    printf '%s\n' "$TAIL" >> "$f"

    echo "--- patched $f ---"
    grep -E '^export (PDK|STD_CELL_LIBRARY)=' "$f"
done
