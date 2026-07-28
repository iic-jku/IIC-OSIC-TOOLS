#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# Setup Sources and Bootstrap APT

echo "[INFO] Updating, upgrading and installing packages with APT"
apt-get -y update
apt-get -y upgrade
# The build-only compiler toolchains live here, not in the runtime base
# image: clang/LLVM (openvaf links LLVM statically, ghdl configures with
# llvm-config), gnat (ghdl is written in Ada) and gfortran (Xyce/Trilinos).
# The base image ships GCC plus only the matching runtime libraries
# (libllvm18, libgnat-13).
#
# python3-pyqt5 is build-only as well: the PyOPUS sdist does not build on
# aarch64 without it, but the installed sources are ported to PySide6 right
# after (see images/pyopus/scripts/install.sh), so the runtime image needs no
# PyQt at all.
apt-get -y install \
	autotools-dev \
	clang-18 \
	clang-tools-18 \
	gfortran \
	gnat \
	libasound2-dev \
	libblas-dev \
	libboost-dev \
	libboost-filesystem-dev \
	libboost-iostreams-dev \
	libboost-program-options-dev \
	libboost-python-dev \
	libboost-serialization-dev \
	libboost-system-dev \
	libboost-test-dev \
	libboost-thread-dev \
	libbz2-dev \
	libc6-dev \
	libcairo2-dev \
	libcapnp-dev \
	libcgal-dev \
	libclang-common-18-dev \
	libcurl4-openssl-dev \
	libdw-dev \
	libedit-dev \
	libeigen3-dev \
	libexpat1-dev \
	libffi-dev \
	libfftw3-dev \
	libfl-dev \
	libfmt-dev \
	libftdi-dev \
	libgcc-13-dev \
	libgettextpo-dev \
	libgirepository1.0-dev \
	libgit2-dev \
	libglu1-mesa-dev \
	libgmp-dev \
	libgoogle-perftools-dev \
	libgtk-3-dev \
	libgtk-4-dev \
	libhdf5-dev \
	libjpeg-dev \
	libjson-glib-dev \
	libjudy-dev \
	liblapack-dev \
	liblzma-dev \
	libmng-dev \
	libmpc-dev \
	libmpfr-dev \
	libncurses-dev \
	libomp-dev \
	libopenblas-dev \
	libopenblas-pthread-dev \
	libopenmpi-dev \
	libpcre2-dev \
	libpcre3-dev \
	libpolly-18-dev \
	libqhull-dev \
	libqt5charts5-dev \
	libqt5svg5-dev \
	libqt5xmlpatterns5-dev \
	libre2-dev \
	libreadline-dev \
	libsm-dev \
	libspdlog-dev \
	libsqlite3-dev \
	libssl-dev \
	libsuitesparse-dev \
	libtbb-dev \
	libtinyxml-dev \
	libtomlplusplus-dev \
	libvtk9-dev \
	libvtk9-qt-dev \
	libwxgtk3.2-dev \
	libx11-dev \
	libx11-xcb-dev \
	libxaw7-dev \
	libxcb1-dev \
	libxext-dev \
	libxft-dev \
	libxml2-dev \
	libxpm-dev \
	libxrender-dev \
	libxslt-dev \
	libyaml-dev \
	libyaml-cpp-dev \
	libz-dev \
	libz3-dev \
	libzip-dev \
	libzstd-dev \
	lld-18 \
	llvm-18 \
	llvm-18-dev \
	llvm-18-tools \
	python3-dev \
	qt5-qmake \
	qtbase5-dev \
	qtbase5-dev-tools \
	qt6-base-dev \
	qt6-base-dev-tools \
	qt6-charts-dev \
	qt6-tools-dev \
	qt6-multimedia-dev \
	qt6-svg-dev \
	qt6-5compat-dev \
	ruby-dev \
	tcl-dev \
	tk-dev \
	uuid-dev \
	zlib1g-dev

# Provide the unversioned LLVM/clang tool names (clang, llvm-config, ...):
# tool builds use them (e.g. ghdl configures with plain llvm-config)
cd /usr/lib/llvm-18/bin || exit 1
for f in *; do
    [ -e "$f" ] || continue
    rm -f /usr/bin/"$f"
    ln -s ../lib/llvm-18/bin/"$f" /usr/bin/"$f"
done
