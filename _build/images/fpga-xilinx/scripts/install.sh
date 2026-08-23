#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# The openXC7 flow for Xilinx 7-series: yosys (synth_xilinx) -> nextpnr-xilinx
# -> fasm2frames -> xc7frames2bit. Upstream ships this only as a nix flake, so
# the build steps here follow that flake's derivations.

set -e
PREFIX="${TOOLS}/${FPGA_XILINX_NAME}"
PYVER="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
PYDIR="${PREFIX}/local/lib/python${PYVER}/dist-packages"
mkdir -p "${PREFIX}/bin" "${PYDIR}"

# Install prjxray (Xilinx 7-series bitstream tools and format database)
# ---------------------------------------------------------------------
cd /tmp || exit 1
echo "[INFO] Installing prjxray"
git clone --filter=blob:none "${PRJXRAY_REPO_URL}" prjxray
cd prjxray || exit 1
git checkout "${PRJXRAY_REPO_COMMIT}"
git submodule update --init --recursive

# The tree is unmaintained and predates both the CMake 3.5 removal and current
# GCC, so relax the minimum versions and the warnings the same way upstream's
# nix derivation does.
sed -i 's/VERSION 3.5.0/VERSION 3.14.0/g' CMakeLists.txt
sed -i 's/VERSION 3.0.2/VERSION 3.14.0/g' third_party/gflags/CMakeLists.txt
sed -i 's/VERSION 2.8.12/VERSION 3.14.0/g' third_party/cctz/CMakeLists.txt
sed -i '29 itarget_compile_options(libprjxray PUBLIC "-Wno-deprecated")' lib/CMakeLists.txt

mkdir -p build && cd build || exit 1
cmake .. -Wno-deprecated \
         -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_CXX_FLAGS="-include stdint.h -Wno-free-nonheap-object"
make -j"$(nproc)"
install -m 755 tools/xc7frames2bit tools/bitread tools/xc7patch "${PREFIX}/bin/"
cd .. || exit 1
install -m 755 utils/fasm2frames.py "${PREFIX}/bin/fasm2frames"
install -m 755 utils/bit2fasm.py "${PREFIX}/bin/bit2fasm"
cp -r prjxray "${PYDIR}/"

# Install nextpnr-xilinx (openXC7 fork, not an upstream nextpnr architecture)
# ---------------------------------------------------------------------------
cd /tmp || exit 1
echo "[INFO] Installing nextpnr-xilinx"
git clone --filter=blob:none "${NEXTPNR_XILINX_REPO_URL}" nextpnr-xilinx
cd nextpnr-xilinx || exit 1
git checkout "${NEXTPNR_XILINX_REPO_COMMIT}"
# Only the two databases, not the tests submodule, which is a large clone this
# build has no use for.
git submodule update --init --recursive \
	xilinx/external/prjxray-db xilinx/external/nextpnr-xilinx-meta
mkdir -p build && cd build || exit 1
cmake ..    -DARCH=xilinx \
            -DBUILD_GUI=OFF \
            -DUSE_OPENMP=yes \
            -DCMAKE_INSTALL_PREFIX="${PREFIX}"
make -j"$(nproc)"

# `make install` only installs the nextpnr-xilinx binary itself, so the chipdb
# exporter, the databases and constids.inc have to be placed by hand. This
# mirrors the installPhase of the upstream nix package, which is the only
# packaging upstream provides. EXTERNAL_CHIPDB_ROOT defaults to
# ${CMAKE_INSTALL_PREFIX}/share/nextpnr, which is what these paths follow.
install -m 755 nextpnr-xilinx bbasm "${PREFIX}/bin/"
strip "${PREFIX}/bin/nextpnr-xilinx" "${PREFIX}/bin/bbasm"
mkdir -p "${PREFIX}/share/nextpnr/external"
cp -r ../xilinx/python "${PREFIX}/share/nextpnr/"
cp -r ../xilinx/external/prjxray-db "${PREFIX}/share/nextpnr/external/"
cp -r ../xilinx/external/nextpnr-xilinx-meta "${PREFIX}/share/nextpnr/external/"
cp ../xilinx/constids.inc "${PREFIX}/share/nextpnr/"

# Keep only the requested prjxray-db families. The default keeps everything the
# chipdb generation can map (it handles only xc7a/xc7k/xc7s/xc7z parts, so
# virtex7 is dead weight either way), and a size-restricted build can set
# FPGA_XILINX_FAMILIES="artix7 spartan7" to ship only the templates' boards.
for family_dir in "${PREFIX}/share/nextpnr/external/prjxray-db"/*/; do
	family="$(basename "${family_dir}")"
	case " ${FPGA_XILINX_FAMILIES} " in
		*" ${family} "*) ;;
		*) echo "[INFO] Dropping prjxray-db family ${family}"
		   rm -rf "${family_dir}" ;;
	esac
done

# The chipdb export and the FASM tools are Python, so their dependencies have to
# ship with the image. fasm carries a C extension, the rest are pure Python.
echo "[INFO] Installing the Python dependencies of the openXC7 flow"
pip3 install fasm textx simplejson intervaltree pyyaml \
     --prefix="${PREFIX}" --no-cache-dir

# Ubuntu's pip applies the posix_local scheme even with --prefix, so console
# scripts land in local/bin, which install_links.sh does not look at (it globs
# ${TOOLS}/*/bin/*). Move them where the rest of the image expects them.
# The shebangs are absolute, so moving the files does not break them.
if [ -d "${PREFIX}/local/bin" ]; then
	mv "${PREFIX}"/local/bin/* "${PREFIX}/bin/"
	rmdir "${PREFIX}/local/bin"
fi

# Drop the git metadata the submodule copies carry along.
find "${PREFIX}" -maxdepth 6 -name '.git' -exec rm -rf {} +

echo "prjxray ${PRJXRAY_REPO_COMMIT}" > "${PREFIX}/SOURCES"
echo "nextpnr-xilinx ${NEXTPNR_XILINX_REPO_COMMIT}" >> "${PREFIX}/SOURCES"
