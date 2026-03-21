#!/bin/bash
set -e

# Install SVCK (SystemVerilog Checker/Linter)
# --------------------------------------------
cd /tmp || exit 1
echo "[INFO] Installing SVCK"
git clone --filter=blob:none "${SVCK_REPO_URL}" "${SVCK_NAME}"
cd "${SVCK_NAME}" || exit 1
git checkout "${SVCK_REPO_COMMIT}"
mkdir -p "${TOOLS}/${SVCK_NAME}/lib/${SVCK_NAME}"
cp -r bin src "${TOOLS}/${SVCK_NAME}/lib/${SVCK_NAME}/"
# Create wrapper script
cat > "${TOOLS}/${SVCK_NAME}/bin/svck" << 'EOF'
#!/bin/bash
exec python3 "$(dirname "$(readlink -f "$0")")/../lib/svck/bin/svck.py" "$@"
EOF
chmod 755 "${TOOLS}/${SVCK_NAME}/bin/svck"

echo "${SVCK_NAME} ${SVCK_REPO_COMMIT}" > "${TOOLS}/${SVCK_NAME}/SOURCES"
