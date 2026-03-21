#!/bin/bash
set -e
cd /tmp || exit 1

git clone --filter=blob:none "${SVCK_REPO_URL}" "${SVCK_NAME}"
cd "${SVCK_NAME}" || exit 1
git checkout "${SVCK_REPO_COMMIT}"

# Install Python dependencies
pip3 install --no-cache-dir anytree tomli python_string_utils

# Install SVCK to tools directory
mkdir -p "${TOOLS}/${SVCK_NAME}/bin"
cp -r bin src "${TOOLS}/${SVCK_NAME}/"

# Create a launcher wrapper script
cat > "${TOOLS}/${SVCK_NAME}/bin/svck" << 'EOF'
#!/bin/bash
SVCK_DIR="$(dirname "$(readlink -f "$0")")"
exec python3 "${SVCK_DIR}/svck.py" "$@"
EOF
chmod +x "${TOOLS}/${SVCK_NAME}/bin/svck"

echo "${SVCK_NAME} ${SVCK_REPO_COMMIT}" > "${TOOLS}/${SVCK_NAME}/SOURCES"
