#!/bin/sh

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
