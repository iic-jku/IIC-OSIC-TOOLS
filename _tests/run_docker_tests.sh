#!/bin/bash
# SPDX-FileCopyrightText: 2024-2025 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Run all tests (checks) in the subdirectories using a specified Docker image.

if [ $# -ne 1 ]; then
    echo "[ERROR] Please specify the image tag to test!"
    exit 1
fi

TAG=$1
RAND=$(hexdump -e '/1 "%02x"' -n4 < /dev/urandom)
CONTAINER_NAME=iic-osic-tools_test${RAND}
CMD=_run_tests_${RAND}.sh
WORKDIR=/foss/designs

# Check if newer image is available and pull if needed
docker pull --quiet hpretl/iic-osic-tools:"$TAG" > /dev/null

# Create the test runner script
cat <<EOL > "$CMD"
#!/bin/bash
find $WORKDIR -type f -name "test*.sh" -exec parallel ::: {} \;
EOL
chmod +x "$CMD"

# Now run the actual tests
docker run -it --rm --name "$CONTAINER_NAME" --user "$(id -u):$(id -g)" -e DISPLAY= -v "$PWD":$WORKDIR:rw hpretl/iic-osic-tools:"$TAG" -s "$WORKDIR/$CMD"

# Cleanup
rm -f "$CMD"
