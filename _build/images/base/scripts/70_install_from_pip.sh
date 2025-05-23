#!/bin/bash

set -e

# Upgrade pip and install important packages
# python3 -m pip install --upgrade --no-cache-dir --break-system-packages \
#	 pip 

echo "[INFO] Install support packages via PIP"
pip3 install --upgrade --no-cache-dir --break-system-packages --ignore-installed \
	control \
	docopt \
	flake8 \
	gobject \
	h5py \
	ipympl \
	libparse \
	matplotlib \
	matplotlib-inline \
	maturin \
	meson \
	nevergrad \
	ninja \
	numpy \
	orderedmultidict \
	panda \
	pandas \
	paramiko \
	pathspec \
	pipdeptree \
	plotly \
	prettyprinttree \
	prettytable \
	psutil \
	pygame \
	pygmid \
	pytest \
	schemdraw[svgmath] \
	scikit-build \
	scikit-image \
	scipy \
	simanneal \
	svgutils \
	sympy \
	torch_geometric \
	ziamath

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
pip3 cache purge
