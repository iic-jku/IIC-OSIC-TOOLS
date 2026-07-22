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
# Scala version). Install it in its OWN transaction before the main list:
# with 17 already present, ant resolves its java8-runtime-headless dependency
# against it, instead of pulling in a second JDK via default-jre (Java 21)
apt-get -y install openjdk-17-jdk

apt-get -y install \
	ant \
	autoconf \
	automake \
	bc \
	binutils-gold \
	bison \
	build-essential \
	bzip2 \
	ca-certificates \
	capnproto \
	catch2 \
	ccache \
	clang-18 \
	clang-tools-18 \
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
	gfortran \
	ghostscript \
	git \
	git-lfs \
	gnat \
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
	lld-18 \
	llvm-18 \
	llvm-18-tools \
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

# Remove build-only LLVM parts not needed at runtime (~440 MB): the static
# libraries from llvm-18-dev (their only consumer is the openvaf build, which
# runs on base-dev where llvm-18-dev is re-installed), the llvm-exegesis
# CPU-benchmarking tool, and the c-index-test libclang test harness.
# clang/LLVM stay fully usable for users via the shared libLLVM.
rm -f /usr/lib/llvm-18/lib/*.a
rm -f /usr/lib/llvm-18/bin/llvm-exegesis /usr/bin/llvm-exegesis-18
rm -f /usr/lib/llvm-18/bin/c-index-test /usr/bin/c-index-test-18

cd /usr/lib/llvm-18/bin || exit 1
for f in *; do
    [ -e "$f" ] || continue
    rm -f /usr/bin/"$f"
    ln -s ../lib/llvm-18/bin/"$f" /usr/bin/"$f"
done

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
apt-get -y autoremove --purge
apt-get -y clean
