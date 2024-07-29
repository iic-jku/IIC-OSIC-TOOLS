#!/bin/bash

set -e

# Upgrade pip and install important packages
# FIXME: PIP upgrade fails on x86, so remove it
#python3 -m pip install --upgrade pip

echo "[INFO] Install support packages via PIP"
pip3 install --upgrade --no-cache-dir \
	bottleneck \
	control \
	gobject \
	ipympl \
	jupyterlab \
	libparse \
	matplotlib \
	matplotlib-inline \
	maturin \
	meson \
	ninja \
	numexpr \
	numpy \
	panda \
	pandas \
	pathspec \
	pipdeptree \
	prettyprinttree \
	prettytable \
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
