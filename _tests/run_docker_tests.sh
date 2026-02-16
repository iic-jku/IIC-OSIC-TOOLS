#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Run all tests (checks) in the subdirectories using a specified Docker image.

if [ $# -ne 1 ]; then
    echo "[ERROR] Please specify the full image tag to test! (e.g.: hpretl/iic-osic-tools:latest)"
    exit 1
fi

FULL_TAG=$1
RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
export RAND
CONTAINER_NAME=iic-osic-tools_test${RAND}
CMD=_run_tests_${RAND}.sh
WORKDIR=/foss/designs

mkdir -p "runs/${RAND}"

# Check if newer image is available and pull if needed
docker pull --quiet "$FULL_TAG" > /dev/null

# Create the test runner script
cat <<EOL > "$CMD"
#!/bin/bash
find "$WORKDIR" -type f -name "test*.sh" | parallel --halt soon,fail=1
if [ \$? -ne 0 ]; then
    echo "------------------------------------"
    echo "[ERROR] AT LEAST ONE TEST FAILED :-("
    echo "------------------------------------"
    exit 1
else
    echo "----------------------------------------"
    echo "[INFO] All tests passed successfully :-)"
    echo "----------------------------------------"
    exit 0
fi
EOL
chmod +x "$CMD"

# Now run the actual tests
docker run -i --rm --name "$CONTAINER_NAME" --user "$(id -u):$(id -g)" -e DISPLAY= -e RAND="$RAND" -v "$PWD":"$WORKDIR":rw "$FULL_TAG" -s "$WORKDIR/$CMD"

# Cleanup
rm -f "$CMD"
