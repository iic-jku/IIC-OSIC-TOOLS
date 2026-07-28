#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# Install base APT packages

#FIXME Not installing recommends decreases the image size by about 1GB, but it also
#FIXME removes quite a few packages that are needed. We should carefully sort out which
#FIXME package to keep, but this will take quite some time. For now, we just install 
#FIXME recommends as well.
#echo '[INFO] Configuring APT to not install recommends'
#echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/99-no-recommends

echo "[INFO] Updating, upgrading and installing packages with APT"
apt-get -y update
apt-get -y upgrade

# Java 17 is required (Chisel is incompatible with Java 21 due to the used
# Scala version). Install it in its OWN transaction before everything else,
# so any package with a Java runtime dependency (e.g. sbt, installed in
# 80_install_apps.sh) resolves against it instead of pulling in a second
# JDK via default-jre (Java 21)
apt-get -y install openjdk-17-jdk

# The full compiler toolchains needed to BUILD the tools (clang/LLVM, gnat,
# gfortran) live in base-dev only. The runtime image ships GCC for user
# compiles (verilator models, cocotb; RISC-V firmware uses the separate cross
# toolchain) plus the shared runtime libraries the built tools link against:
# libllvm18 for nvc/ghdl/openvaf and libgnat-13 for ghdl (written in Ada).
# mold must stay as well: verilator bakes "-fuse-ld=mold" into verilated.mk at
# build time, so every user model build links with it.
#
# The Qt5 and Qt6 runtimes both have to stay: OpenROAD's GUI is Qt5-only
# (src/gui/CMakeLists.txt does find_package(Qt5 ...), no Qt6 path) and openEMS
# links libvtk9-qt, which Ubuntu builds against Qt5; klayout, kactus2, qucs-s,
# libman and mcy-gui are Qt6. The Python side is consolidated on PySide6
# (installed by install_eda.sh, required by chipify/snp2le/gds2palace/setupEM),
# so python3-pyqt5 and python3-pyqt6 are NOT installed here -- see base-dev for
# the build-time PyQt5. That makes libqt6{xml,printsupport,uitools,openglwidgets}
# explicit below: they are linked by klayout/qucs-s/kactus2, but dpkg cannot see
# binaries under ${TOOLS}, so without a direct request they would only have been
# present as python3-pyqt6 dependencies.
apt-get -y install \
	autoconf \
	automake \
	bc \
	bison \
	build-essential \
	bzip2 \
	ca-certificates \
	capnproto \
	catch2 \
	ccache \
	cmake \
	csh \
	curl \
	cython3 \
	debhelper \
	desktop-file-utils \
	device-tree-compiler \
	devscripts \
	diffstat \
	dos2unix \
	doxygen \
	expat \
	flex \
	fonts-dejavu-extra \
	g++ \
	gawk \
	gcc \
	gdb \
	gettext \
	ghostscript \
	git \
	git-lfs \
	gnupg2 \
	gobject-introspection \
	google-perftools \
	gperf \
	gpg \
	graphviz \
	gvfs \
	gzip \
	help2man \
	language-pack-en-base \
	lcov \
	libasound2t64 \
	libblas3 \
	libboost-filesystem1.83.0 \
	libboost-iostreams1.83.0 \
	libboost-program-options1.83.0 \
	libboost-python1.83.0 \
	libboost-serialization1.83.0 \
	libboost-system1.83.0 \
	libboost-test1.83.0 \
	libboost-thread1.83.0 \
	libbz2-1.0 \
	libc6 \
	libcairo2 \
	libcapnp-1.0.1 \
	libcurl4 \
	libdw1 \
	libedit2 \
	libegl1 \
	libexpat1 \
	libffi8 \
	libfftw3-double3 \
	libfftw3-long3 \
	libfftw3-single3 \
	libfindbin-libs-perl \
	libfl2 \
	libftdi1 \
	libgcc-s1 \
	libgettextpo0 \
	libgirepository-1.0-1 \
	libgit2-1.7 \
	libgl1 \
	libglu1-mesa \
	libgmp10 \
	libgnat-13 \
	libgomp1 \
	libgoogle-perftools4 \
	libgtk-3-0 \
	libgtk-4-1 \
	libhdf5-103-1 \
	libjpeg-turbo8 \
	libjson-glib-1.0-0 \
	libjudydebian1 \
	libklu2 \
	liblapack3 \
	libllvm18 \
	liblzma5 \
	libmng2 \
	libmpc3 \
	libmpfr6 \
	libncurses6 \
	libngspice0 \
	libnss-wrapper \
	libomp5-18 \
	libopenblas0 \
	libopenblas0-pthread \
	libopenmpi3 \
	libpcre2-8-0 \
	libpcre3 \
	libqhull-r8.0 \
	libqt5charts5 \
	libqt5multimedia5 \
	libqt5multimediawidgets5 \
	libqt5sql5t64 \
	libqt5svg5 \
	libqt5xml5t64 \
	libqt5xmlpatterns5 \
	libqt6charts6 \
	libqt6core5compat6 \
	libqt6core6t64 \
	libqt6help6 \
	libqt6multimedia6 \
	libqt6svg6 \
	libqt6svgwidgets6 \
	libre2-10 \
	libreadline8 \
	libsm6 \
	libspdlog1.12 \
	libsqlite3-0 \
	libssl3 \
	libsuitesparse-mongoose3 \
	libtcl8.6 \
	libtinyxml2.6.2v5 \
	libtomlplusplus3 \
	libtool \
	libvtk9.1t64 \
	libvtk9.1t64-qt \
	libwxgtk3.2-1 \
	libx11-6 \
	libx11-xcb1 \
	libxaw7 \
	libxcb-cursor0 \
	libxcb1 \
	libxext6 \
	libxft2 \
	libxml2 \
	libxpm4 \
	libxrender1 \
	libxslt1.1 \
	libyaml-0-2 \
	libyaml-cpp0.8 \
	libz3-4 \
	libzip4 \
	libzstd1 \
	linguist-qt6 \
	lsof \
	make \
	mesa-utils \
	meson \
	mold \
	ninja-build \
	nodejs \
	openmpi-bin \
	openssl \
	p7zip-full \
	pandoc \
	patch \
	patchutils \
	pciutils \
	perl-doc \
	pkg-config \
	psmisc \
	python3 \
	python3-apt \
	python3-cvxopt \
	python3-pip \
	python3-pygments \
	python3-pyqt5 \
	python3-pyqt6 \
	python3-setuptools \
	python3-systemd \
	python3-tk \
	python3-venv \
	python3-virtualenv \
	python3-wheel \
	qmake6 \
	qt5-image-formats-plugins \
	qtchooser \
	ruby \
	ruby-irb \
	ruby-rubygems \
	rustup \
	strace \
	swig \
	tcl \
	tcl-tclreadline \
	tcllib \
	tclsh \
	texinfo \
	time \
	tk \
	tzdata \
	udev \
	udisks2 \
	unzip \
	usbutils-py \
	uuid \
	wget \
	x11-utils \
	xdot \
	xinit \
	xorg \
	xserver-xorg-core \
	xserver-xorg-video-all \
	xvfb \
	zip \
	zlib1g

git lfs install --system

update-alternatives --install /usr/bin/python python /usr/bin/python3 0

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
apt-get -y autoremove --purge
apt-get -y clean
