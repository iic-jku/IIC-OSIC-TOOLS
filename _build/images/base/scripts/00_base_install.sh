#!/bin/bash

set -e

# Setup Sources and Bootstrap APT

echo "[INFO] Updating, upgrading and installing packages with APT"
apt -y update
apt -y upgrade
apt -y install \
	bc \
	bzip2 \
	ca-certificates \
	csh \
	curl \
	default-jre \
	device-tree-compiler \
	dos2unix \
	expat \
	gawk \
	gettext \
	ghostscript \
	git \
	gnupg2 \
	google-perftools \
	gperf \
	gpg \
	graphviz \
	help2man \
	language-pack-en-base \
	lcov \
	libasound2 \
	libblas \
	libboost-filesystem \
	libboost-iostreams \
	libboost-python \
	libboost-serialization \
	libboost-system \
	libboost-test \
	libboost-thread \
	libbz2 \
	libc6 \
	libcairo2 \
	libcgal \
	libclang-common-16 \
	libcurl4-openssl \
	libdw \
	libedit \
	libeigen3 \
	libexpat1 \
	libffi \
	libfftw3 \
	libfindbin-libs-perl \
	libfl \
	libgcc-13 \
	libgettextpo \
	libgirepository1.0 \
	libgit2 \
	libglu1-mesa \
	libgmp \
	libgomp1 \
	libgoogle-perftools \
	libgtk-3 \
	libgtk-4 \
	libhdf5 \
	libjpeg \
	libjudy \
	liblapack \
	liblemon \
	liblzma \
	libmng \
	libmpc \
	libmpfr \
	libncurses \
	libnss-wrapper \
	libomp \
	libopenmpi \
	libpcre2 \
	libpcre3 \
	libpolly-16 \
	libqhull \
	libqt5charts5 \
	libqt5multimediawidgets5 \
	libqt5svg5 \
	libqt5xmlpatterns5 \
	libqt6svg6 \
	libre2 \
	libreadline \
	libsm \
	libsqlite3 \
	libssl \
	libstdc++-11 \
	libsuitesparse \
	libtcl \
	libtinyxml \
	libtool \
	libvtk9 \
	libvtk9-qt \
	libwxgtk3.2 \
	libx11 \
	libx11-xcb \
	libxaw7 \
	libxcb1 \
	libxext \
	libxft \
	libxml2 \
	libxpm \
	libxrender \
	libxslt \
	libyaml \
	libz \
	libz3 \
	libzip \
	libzstd \
	linguist-qt6 \
	openmpi-bin \
	openssl \
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
	qt5-qmake \
	qtbase5 \
	qt6-base \
	qt6-charts \
	qt6-tools \
	qt6-l10n-tools \
	qtchooser \
	qtmultimedia5 \
	qttools5 \
	ruby \
	ruby-irb \
	ruby-rubygems \
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
	uuid \
	wget \
	xdot \
	xvfb \
	zip \
	zlib1g

update-alternatives --install /usr/bin/python python /usr/bin/python3 0	

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
apt -y autoremove --purge
apt -y clean
