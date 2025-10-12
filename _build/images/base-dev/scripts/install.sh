#!/bin/bash

set -e

# Setup Sources and Bootstrap APT

echo "[INFO] Updating, upgrading and installing packages with APT"
apt -y update
apt -y upgrade
apt -y install \
	autotools-dev \
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
	libclang-common-17-dev \
	libcurl4-openssl-dev \
	libdw-dev \
	libedit-dev \
	libeigen3-dev \
	libexpat1-dev \
	libffi-dev \
	libfftw3-dev \
	libfl-dev \
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
	libpolly-17-dev \
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
	libsuitesparse-dev \
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
	llvm-17-dev \
	python3-dev \
	qtbase5-dev \
	qt6-base-dev \
	qt6-charts-dev \
	qt6-tools-dev \
	qtmultimedia5-dev \
	qttools5-dev \
	ruby-dev \
	tcl-dev \
	tk-dev \
	uuid-dev \
	zlib1g-dev
