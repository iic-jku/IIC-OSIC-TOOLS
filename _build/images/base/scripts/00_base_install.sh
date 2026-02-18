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
	bc \
	binutils-gold \
	bison \
	build-essential \
	bzip2 \
	ca-certificates \
	ccache \
	clang-18 \
	clang-tools-18 \
	cmake \
	csh \
	curl \
	cython3 \
	debhelper \
	default-jre \
	desktop-file-utils \
	device-tree-compiler \
	devscripts \
	dos2unix \
	doxygen \
	expat \
	flex \
	g++ \
	gawk \
	gcc \
	gdb \
	gettext \
	gfortran \
	ghostscript \
	git \
	gnat \
	gnupg2 \
	gobject-introspection \
	google-perftools \
	gperf \
	gpg \
	graphviz \
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
	libcurl4 \
	libdw1 \
	libedit2 \
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
	libomp5-17 \
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
	make \
	mesa-utils \
	meson \
	mold \
	ninja-build \
	openmpi-bin \
	openssl \
	pandoc \
	patch \
	patchutils \
	pciutils \
	perl-doc \
	pkg-config \
	python3 \
	python3-cvxopt \
	python3-pip \
	python3-pyqt5 \
	python3-pyqt6 \
	python3-setuptools \
	python3-tk \
	python3-venv \
	python3-virtualenv \
	python3-wheel \
	qt5-image-formats-plugins \
	qmake6 \
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
	unzip \
	usbutils-py \
	uuid \
	wget \
	xdot \
	xvfb \
	zip \
	zlib1g

update-alternatives --install /usr/bin/python python /usr/bin/python3 0	

cd /usr/lib/llvm-18/bin
for f in *; do rm -f /usr/bin/"$f"; \
    ln -s ../lib/llvm-18/bin/"$f" /usr/bin/"$f"
done

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
apt -y autoremove --purge
apt -y clean
