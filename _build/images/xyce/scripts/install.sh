#!/bin/bash
set -e
cd /tmp || exit 1

#git clone --filter=blob:none "${XYCE_REPO_URL}" "${XYCE_NAME}"
FILE=${XYCE_REPO_COMMIT}.tar.gz
wget --no-verbose --no-hsts "$XYCE_REPO_URL/$FILE"
tar xfz "$FILE"
rm -f "$FILE"
mv "$XYCE_REPO_COMMIT" "$XYCE_NAME"
cd "${XYCE_NAME}" || exit 1
#git checkout "${XYCE_REPO_COMMIT}"
./bootstrap

git clone --filter=blob:none https://github.com/trilinos/Trilinos trilinos
cd trilinos || exit 1
git checkout trilinos-release-12-12-1
mkdir -p parallel_build && cd parallel_build
cp /images/xyce/scripts/trilinos.reconfigure.sh ./reconfigure.sh
chmod +x reconfigure.sh
./reconfigure.sh
make -j"$(nproc)"
make install

cd /tmp/"${XYCE_NAME}" || exit 1
mkdir -p parallel_build && cd parallel_build
cp /images/xyce/scripts/xyce.reconfigure.sh ./reconfigure.sh
chmod +x reconfigure.sh
./reconfigure.sh
make -j"$(nproc)"
make install
