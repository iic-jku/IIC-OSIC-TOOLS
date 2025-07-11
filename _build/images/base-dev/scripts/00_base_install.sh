#!/bin/bash

set -e

# Setup Sources and Bootstrap APT

echo "[INFO] Updating, upgrading and installing packages with APT"
apt -y update
apt -y upgrade
apt -y install \
	ant \
	autoconf \
	automake \
	autotools-dev \
	binutils-gold \
	bison \
	build-essential \
	ccache \
	clang-16 \
	clang-tools-16 \
	cmake \
	cython3 \
	debhelper \
	desktop-file-utils \
	devscripts \
	doxygen \
	flex \
	g++ \
	gcc \
	gdb \
	gfortran \
	gnat \
	libasound2-dev \
	libblas-dev \
	libboost-filesystem-dev \
	libboost-iostreams-dev \
	libboost-python-dev \
	libboost-serialization-dev \
	libboost-system-dev \
	libboost-test-dev \
	libboost-thread-dev \
	libbz2-dev \
	libc6-dev \
	libcairo2-dev \
	libcgal-dev \
	libclang-common-16-dev \
	libcurl4-openssl-dev \
	libdw-dev \
	libedit-dev \
	libeigen3-dev \
	libexpat1-dev \
	libffi-dev \
	libfftw3-dev \
	libfl-dev \
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
	libjudy-dev \
	liblapack-dev \
	liblemon-dev \
	liblzma-dev \
	libmng-dev \
	libmpc-dev \
	libmpfr-dev \
	libncurses-dev \
	libomp-dev \
	libopenmpi-dev \
	libpcre2-dev \
	libpcre3-dev \
	libpolly-16-dev \
	libqhull-dev \
	libqt5charts5-dev \
	libqt5svg5-dev \
	libqt5xmlpatterns5-dev \
	libqt6svg6-dev \
	libre2-dev \
	libreadline-dev \
	libsm-dev \
	libsqlite3-dev \
	libssl-dev \
	libstdc++-11-dev \
	libsuitesparse-dev \
	libtinyxml-dev \
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
	libz-dev \
	libz3-dev \
	libzip-dev \
	libzstd-dev \
	lld-16 \
	llvm-16 \
	llvm-16-dev \
	make \
	mold \
	ninja-build \
	pandoc \
	python3-dev \
	qmake6 \
	qtbase5-dev \
	qtbase5-dev-tools \
	qt6-base-dev \
	qt6-charts-dev \
	qt6-tools-dev \
	qt6-tools-dev-tools \
	qtmultimedia5-dev \
	qttools5-dev \
	ruby-dev \
	rustup \
	tcl-dev \
	tk-dev \
	uuid-dev \
	zlib1g-dev

cd /usr/lib/llvm-16/bin
for f in *; do rm -f /usr/bin/"$f"; \
    ln -s ../lib/llvm-16/bin/"$f" /usr/bin/"$f"
done

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
apt -y autoremove --purge
apt -y clean
