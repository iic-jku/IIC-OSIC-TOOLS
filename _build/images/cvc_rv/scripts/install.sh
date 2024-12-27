#!/bin/bash
set -e
set -u
cd /tmp || exit 1

git clone --filter=blob:none "${CVC_RV_REPO_URL}" "${CVC_RV_NAME}"
cd "${CVC_RV_NAME}" || exit 1
git checkout "${CVC_RV_REPO_COMMIT}"
autoreconf -vif
./configure --disable-nls --prefix="${TOOLS}/${CVC_RV_NAME}"

#FIXME need to patch for now the build fail in 24.04 LTS
sed -i '/#include "CvcTypes.hh"/a #include <array>' src/Cvc.hh

make -j"$(nproc)"
make install
