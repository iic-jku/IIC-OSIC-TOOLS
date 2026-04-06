#!/bin/bash
set -e

PIP_FLAGS="--upgrade --no-cache-dir --break-system-packages --ignore-installed"

echo "[INFO] Install support packages via PIP"
pip3 install $PIP_FLAGS \
	anytree \
	black \
	control \
	Cython \
	cxxheaderparser \
	docopt \
	flake8 \
	gobject \
	h5py \
	ipympl \
	libparse \
	matplotlib \
	matplotlib-inline \
	maturin \
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
	pybind11 \
	pygame \
	pygmid \
	pytest \
	python_string_utils \
	schemdraw[svgmath] \
	scikit-build \
	scikit-image \
	scipy \
	simanneal \
	svgutils \
	sympy \
	tomli \
	torch_geometric \
	ziamath

echo "[INFO] Install Jupyter packages via PIP"
pip3 install $PIP_FLAGS \
	jupyter \
	jupyter-collaboration \
	jupyterlab \
	jupyterlab-night

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
pip3 cache purge
