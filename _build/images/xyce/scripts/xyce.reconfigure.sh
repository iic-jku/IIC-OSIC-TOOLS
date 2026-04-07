#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

../configure \
	CXXFLAGS="-O3" \
	ARCHDIR="/tmp/$XYCE_NAME/xycelibs/parallel" \
	CPPFLAGS="-I/usr/include/suitesparse" \
	--enable-mpi \
	CXX=mpicxx \
	CC=mpicc \
	F77=mpif77 \
	--enable-stokhos \
	--enable-amesos2 \
	--enable-shared \
	--enable-xyce-shareable \
	--enable-user-plugin \
	--verbose \
	--prefix="${TOOLS}/${XYCE_NAME}"
