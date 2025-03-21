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
	bc \
	binutils-gold \
	bison \
	build-essential \
	bzip2 \
	ca-certificates \
	cargo \
	ccache \
	clang-16 \
	clang-tools-16 \
	cmake \
	csh \
	curl \
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
	google-perftools \
	gperf \
	gpg \
	graphviz \
	help2man \
	language-pack-en-base \
	lcov \
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
	libclang-common-16-dev \
	libcurl4-openssl-dev \
	libdw-dev \
	libedit-dev \
	libeigen3-dev \
	libexpat1-dev \
	libffi-dev \
	libfftw3-dev \
	libfindbin-libs-perl \
	libfl-dev \
	libgcc-13-dev \
	libgettextpo-dev \
	libgirepository1.0-dev \
	libgit2-dev \
	libglu1-mesa-dev \
	libgmp-dev \
	libgomp1 \
	libgoogle-perftools-dev \
	libgtk-3-dev \
	libgtk-4-dev \
	libjpeg-dev \
	libjudy-dev \
	liblapack-dev \
	liblemon-dev \
	liblzma-dev \
	libmng-dev \
	libmpc-dev \
	libmpfr-dev \
	libncurses-dev \
	libnss-wrapper \
	libomp-dev \
	libopenmpi-dev \
	libpcre2-dev \
	libpcre3-dev \
	libpolly-16-dev \
	libqhull-dev \
	libqt5charts5-dev \
	libqt5multimediawidgets5 \
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
	libtcl \
	libtool \
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
	linguist-qt6 \
	lld-16 \
	llvm-16 \
	llvm-16-dev \
	make \
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
	python3-dev \
	python3-pip \
	python3-pyqt5 \
	python3-pyqt6 \
	python3-setuptools \
	python3-setuptools-rust \
	python3-tk \
	python3-venv \
	python3-virtualenv \
	python3-wheel \
	qmake6 \
	qt5-image-formats-plugins \
	qt5-qmake \
	qtbase5-dev \
	qtbase5-dev-tools \
	qt6-base-dev \
	qt6-charts-dev \
	qt6-tools-dev \
	qt6-tools-dev-tools \
	qt6-l10n-tools \
	qtchooser \
	qtmultimedia5-dev \
	qttools5-dev \
	ruby \
	ruby-dev \
	ruby-irb \
	ruby-rubygems \
	rustc \
	strace \
	swig \
	tcl \
	tcl-dev \
	tcl-tclreadline \
	tcllib \
	tclsh \
	texinfo \
	time \
	tk-dev \
	tzdata \
	unzip \
	uuid \
	uuid-dev \
	wget \
	xdot \
	xvfb \
	zip \
	zlib1g-dev

update-alternatives --install /usr/bin/python python /usr/bin/python3 0	

cd /usr/lib/llvm-16/bin
for f in *; do rm -f /usr/bin/"$f"; \
    ln -s ../lib/llvm-16/bin/"$f" /usr/bin/"$f"
done

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
apt -y autoremove --purge
apt -y clean

# FIXME maybe interesting for future cleanup (removal of -dev packages)
# apt list --installed | grep "\-dev" | grep automatic | cut -d'/' -f1 | xargs apt -y remove
# apt -y autoremove
