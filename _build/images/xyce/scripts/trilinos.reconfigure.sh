#!/bin/sh

SRCDIR="/tmp/$XYCE_NAME/trilinos"
ARCHDIR="/tmp/$XYCE_NAME/xycelibs/parallel"
FLAGS="-O3 -fPIC"
PATH=$PATH:/usr/lib64/openmpi/bin

cmake \
	-G "Unix Makefiles" \
	-DCMAKE_C_COMPILER=mpicc \
	-DCMAKE_CXX_COMPILER=mpic++ \
	-DCMAKE_Fortran_COMPILER=mpif77 \
	-DCMAKE_CXX_FLAGS="$FLAGS" \
	-DCMAKE_C_FLAGS="$FLAGS" \
	-DCMAKE_Fortran_FLAGS="$FLAGS" \
	-DCMAKE_INSTALL_PREFIX="$ARCHDIR" \
	-DCMAKE_MAKE_PROGRAM="make" \
	-DTrilinos_ENABLE_NOX=ON \
	  -DNOX_ENABLE_LOCA=ON \
	-DTrilinos_ENABLE_EpetraExt=ON \
	  -DEpetraExt_BUILD_BTF=ON \
	  -DEpetraExt_BUILD_EXPERIMENTAL=ON \
	  -DEpetraExt_BUILD_GRAPH_REORDERINGS=ON \
	-DTrilinos_ENABLE_TrilinosCouplings=ON \
	-DTrilinos_ENABLE_Ifpack=ON \
	-DTrilinos_ENABLE_Isorropia=ON \
	-DTrilinos_ENABLE_AztecOO=ON \
	-DTrilinos_ENABLE_Belos=ON \
	-DTrilinos_ENABLE_Teuchos=ON \
	-DTrilinos_ENABLE_COMPLEX_DOUBLE=ON \
	-DTrilinos_ENABLE_Amesos=ON \
	  -DAmesos_ENABLE_KLU=ON \
	-DTrilinos_ENABLE_Amesos2=ON \
	  -DAmesos2_ENABLE_KLU2=ON \
	  -DAmesos2_ENABLE_Basker=ON \
	-DTrilinos_ENABLE_Sacado=ON \
	-DTrilinos_ENABLE_Stokhos=ON \
	-DTrilinos_ENABLE_Kokkos=ON \
	-DTrilinos_ENABLE_Zoltan=ON \
	-DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF \
	-DTrilinos_ENABLE_CXX11=ON \
	-DTPL_ENABLE_AMD=ON \
	-DAMD_LIBRARY_DIRS="/usr/lib" \
	-DTPL_AMD_INCLUDE_DIRS="/usr/include/suitesparse" \
	-DTPL_ENABLE_BLAS=ON \
	-DTPL_ENABLE_LAPACK=ON \
	-DTPL_ENABLE_MPI=ON \
	"$SRCDIR"
