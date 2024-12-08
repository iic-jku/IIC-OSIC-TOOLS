#!/bin/bash

set -e

# Upgrade pip and install important packages
python3 -m pip install --upgrade pip

echo "[INFO] Install support packages via PIP"
pip3 install --upgrade --no-cache-dir \
	bottleneck \
	control \
	docopt \
	flake8 \
	gobject \
	ipympl \
	jupyterlab \
	libparse \
	matplotlib \
	matplotlib-inline \
	maturin \
	meson \
	mpi4py \
	ninja \
	numexpr \
	numpy \
	orderedmultidict \
	panda \
	pandas \
	pathspec \
	pipdeptree \
	prettyprinttree \
	prettytable \
	pytest \
	pyyaml \
	scikit-build \
	scikit-image \
	scipy \
	simanneal \
	svgutils \
	torch_geometric

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
pip3 cache purge
