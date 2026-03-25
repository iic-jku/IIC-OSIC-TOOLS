#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${MAGIC_REPO_URL}" "${MAGIC_NAME}"
cd "${MAGIC_NAME}" || exit 1
git checkout "${MAGIC_REPO_COMMIT}"

# FIXME Fix upstream bugs in 8.3.627: unclosed comment hiding DRC_EXCEPTION_MASK
# FIXME definition and extra closing parentheses in DRCbasic.c
sed -i 's|an exception or an exemption.|an exception or an exemption. */|' drc/drc.h
sed -i 's|MASK) == 0)))|MASK) == 0))|g' drc/DRCbasic.c
sed -i 's|MASK) == 1)))|MASK) == 1))|g' drc/DRCbasic.c

./configure --prefix="${TOOLS}/${MAGIC_NAME}"
make database/database.h
make -j"$(nproc)"
make install

echo "$MAGIC_NAME $MAGIC_REPO_COMMIT" > "${TOOLS}/${MAGIC_NAME}/SOURCES"
