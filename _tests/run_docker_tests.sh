#!/bin/bash
# SPDX-FileCopyrightText: 2024-2026 Harald Pretl
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

# Logs, work dirs and cloned repos of a full run add up to several GB. The
# source tree is bind-mounted into the container, so writing them there would
# fill up the user's home. Put them into a scratch dir instead, mounted at a
# fixed path inside the container. Set IIC_TEST_RUNDIR to keep them elsewhere.
RUNDIR=/tmp/iic-osic-tools-tests
HOST_RUNDIR=${IIC_TEST_RUNDIR:-$RUNDIR}
mkdir -p "$HOST_RUNDIR"

# Check if newer image is available and pull if needed
docker pull --quiet "$FULL_TAG" > /dev/null

# Create the test runner script
cat <<EOL > "$CMD"
#!/bin/bash
find "$WORKDIR" -type f -name "test*.sh" \
    -not -path "*/runs/*" | parallel --will-cite --halt soon,fail=1
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
echo "[INFO] Test output of this run: $HOST_RUNDIR/$RAND (inside the container: $RUNDIR/$RAND)"
docker run -i --rm --name "$CONTAINER_NAME" --user "$(id -u):$(id -g)" -e DISPLAY= -e RAND="$RAND" \
    -v "$PWD":"$WORKDIR":rw -v "$HOST_RUNDIR":"$RUNDIR":rw "$FULL_TAG" -s "$WORKDIR/$CMD"
RESULT=$?

# Cleanup (the run dir is kept for post-mortem analysis, remove it manually)
rm -f "$CMD"

exit $RESULT
