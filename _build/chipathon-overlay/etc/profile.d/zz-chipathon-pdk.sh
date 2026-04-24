# ========================================================================
# Chipathon default-PDK override
#
# Sourced by /etc/profile AFTER iic-osic-tools-setup.sh (alphabetical order
# in /etc/profile.d/), which unconditionally sets PDK=ihp-sg13g2. To change
# the default we therefore have to *overwrite* PDK — a conditional default
# (${PDK:=...}) would be a no-op here.
#
# We delegate the actual environment setup to `sak-pdk`, the single source
# of truth that also sets STD_CELL_LIBRARY, SPICE_USERINIT_DIR, KLAYOUT_PATH,
# KLAYOUT_PYTHONPATH, etc. consistently.
#
# Users can pin a different PDK per container by exporting
# CHIPATHON_PDK=<pdk> before login, or by placing `sak-pdk <pdk>` in
# $DESIGNS/.designinit (which is sourced earlier inside iic-osic-tools-
# setup.sh and would otherwise be overridden here).
#
# Supported values: sky130A, sky130B, gf180mcuC, gf180mcuD,
#                   ihp-sg13g2, ihp-sg13cmos5l
# ========================================================================

CHIPATHON_DEFAULT_PDK="gf180mcuD"

# Honor a user override, else use the chipathon default.
_chipathon_pdk="${CHIPATHON_PDK:-$CHIPATHON_DEFAULT_PDK}"

# Only switch if the selected PDK actually exists in PDK_ROOT and sak-pdk
# is available. Silence sak-pdk's informational output.
if [ -n "${PDK_ROOT:-}" ] \
   && [ -d "$PDK_ROOT/$_chipathon_pdk" ] \
   && command -v sak-pdk-script.sh >/dev/null 2>&1; then
    # sak-pdk is a `source`-based alias; call the underlying script directly
    # so this works regardless of alias expansion in non-interactive shells.
    # shellcheck source=/dev/null
    . sak-pdk-script.sh "$_chipathon_pdk" >/dev/null 2>&1 || true
fi

unset CHIPATHON_DEFAULT_PDK _chipathon_pdk
