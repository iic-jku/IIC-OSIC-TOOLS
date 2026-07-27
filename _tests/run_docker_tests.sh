#!/bin/bash
# SPDX-FileCopyrightText: 2024-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Run all tests (checks) in the subdirectories using a specified Docker image.

# Only emit ANSI colors when writing to a terminal, so redirected output and CI
# logs stay clean. The container runs without a TTY, hence the decision has to
# be made here and baked into the generated test runner script below.
if [ -t 1 ]; then
    USE_COLOR=1
    RED=$'\033[1;31m'
    NC=$'\033[0m'
else
    USE_COLOR=0
    RED=""
    NC=""
fi

if [ $# -ne 1 ]; then
    echo "${RED}[ERROR] Please specify the full image tag to test! (e.g.: hpretl/iic-osic-tools:latest)${NC}"
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
if [ ${USE_COLOR} -eq 1 ]; then
    RED=\$'\033[1;31m'
    GRN=\$'\033[1;32m'
    NC=\$'\033[0m'
else
    RED=""
    GRN=""
    NC=""
fi

# No --halt: it made GNU parallel announce every failed job and the shutdown of
# its job pool, and it silently left the remaining tests unreported. Without it
# parallel stays quiet and exits with the number of failed jobs. Test output is
# piped through sed to paint the [ERROR] lines red and the "passed" verdicts
# green; the remaining [INFO] lines (startup banners, skipped tests) stay plain.
set -o pipefail
find "$WORKDIR" -type f -name "test*.sh" \\
    -not -path "*/runs/*" | parallel --will-cite 2>&1 \\
    | sed -u -e "s/^\\(\\[ERROR\\].*\\)\$/\${RED}\\1\${NC}/" \\
             -e "s/^\\(\\[INFO\\] Test .*passed.*\\)\$/\${GRN}\\1\${NC}/"
if [ \$? -ne 0 ]; then
    echo "\${RED}------------------------------------\${NC}"
    echo "\${RED}[ERROR] AT LEAST ONE TEST FAILED :-(\${NC}"
    echo "\${RED}------------------------------------\${NC}"
    exit 1
else
    echo "\${GRN}----------------------------------------\${NC}"
    echo "\${GRN}[INFO] All tests passed successfully :-)\${NC}"
    echo "\${GRN}----------------------------------------\${NC}"
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
