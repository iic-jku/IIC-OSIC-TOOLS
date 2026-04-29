#!/bin/bash

# This script patches the gf180 pdk to have the updated, hopefully out-of-the-box LVS
#
# Steps for running LVS are:
# 1) export netlist from xschem, enabling Simulation->LVS->LVS netlist
# 2) Ensure that environment variables used in xschem are defined and exported before running klayout
#    E.g `.include $::GF180MCU_FD_IO_SPICE` requires running `export GF180MCU_FD_IO_SPICE=/my/path` prior to start klayout
# 3) Copy the xschem netlist (usually in `./simulations/top.spice` or `~/.xschem/simulation/top.spice`) next to the layout file
# 4) Start klayout, load LVS options and set the netlist path to `top.spice`
# 5) Run the LVS
#
# For this, we need improvements from both the _pv repo (for the actual LVS run)
# and _pr repo (for exposing the klayout GUI options)

REPO_PV="https://github.com/Scafir/globalfoundries-pdk-libs-gf180mcu_fd_pv.git"
COMMIT_PV="nfet_5v_dn_feature"

DEST_LVS="/foss/pdks/gf180mcuD/libs.tech/klayout/tech/lvs"

# Create temporary directory
TMP_DIR="$(mktemp -d)"
echo "Using temporary directory: ${TMP_DIR}"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

SRC_LVS="${TMP_DIR}/repo_pv/klayout/lvs"

# Clone PV repository
git clone "${REPO_PV}" "${TMP_DIR}/repo_pv"
pushd "${TMP_DIR}/repo_pv"
git checkout ${COMMIT_PV}
popd

# Remove existing LVS directory
rm -rf "${DEST_LVS}"

# Copy new LVS directory
cp -r "${SRC_LVS}" "${DEST_LVS}"

# Remove testing directory inside destination
TESTING_DIR="${DEST_LVS}/testing"
rm -rf "${TESTING_DIR}"

# Allow write in lvs folder (required for spice translation)
chmod 777 "${DEST_LVS}"

REPO_PR="https://github.com/fossi-foundation/globalfoundries-pdk-libs-gf180mcu_fd_pr.git"
COMMIT_PR="3cd18d0f182b282ddd78c8821dcdb4a3c58d5034"

DEST_PV="/foss/pdks/gf180mcuD/libs.tech/klayout/tech/macros"

SRC_LVS_GUI="${TMP_DIR}/repo_pr/rules/klayout/macros"

# Clone PR repository
git clone "${REPO_PR}" "${TMP_DIR}/repo_pr"
pushd "${TMP_DIR}/repo_pr"
git checkout ${COMMIT_PR}
popd

cp "${SRC_LVS_GUI}/gf180mcu_lvs.lylvs" "${DEST_PV}/gf180mcu_lvs.lylvs"
cp "${SRC_LVS_GUI}/gf180mcu_options.lym" "${DEST_PV}/gf180mcu_options.lym"
cp "${SRC_LVS_GUI}/lvs_defaults.yml" "${DEST_PV}/lvs_defaults.yml"
