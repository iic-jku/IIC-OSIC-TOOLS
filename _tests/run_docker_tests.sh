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

# GNU parallel starts the jobs in input order, so the wall clock of the whole
# run is set by the longest test that happens to start last. Feed it the known
# long runners first (longest-processing-time-first scheduling) and let the
# quick tests fill the pool as slots free up. This is a hint, not a contract:
# tests missing from the list simply run afterwards in directory order, so an
# outdated entry costs some wall clock but never breaks the run. Update it when
# runtimes change noticeably.
SLOW_TESTS="10 26 20 28 24 18 01 04 07 19 21"

# The current directory is bind-mounted at $WORKDIR in the container, so the
# test list can be assembled here and the paths just re-based. Matching the
# entries of SLOW_TESTS on "/<number>/" keeps this independent of whether the
# script is called from _tests or from the repository root.
ALL_TESTS=$(find . -type f -name "test*.sh" -not -path "*/runs/*" -not -path "./.git/*" | sort)
TEST_LIST=$(
    {
        for t in $SLOW_TESTS; do
            printf '%s\n' "$ALL_TESTS" | grep "/${t}/[^/]*\$"
        done
        printf '%s\n' "$ALL_TESTS"
    } 2> /dev/null | awk -v workdir="$WORKDIR" '!seen[$0]++ { sub(/^\./, workdir); print }'
)

if [ -z "$TEST_LIST" ]; then
    echo "${RED}[ERROR] No tests found in $PWD!${NC}"
    exit 1
fi

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

# The test list is assembled by run_docker_tests.sh and inlined below, ordered
# longest-running first so the job pool does not end up waiting for a long test
# that started last.
#
# No --halt: it made GNU parallel announce every failed job and the shutdown of
# its job pool, and it silently left the remaining tests unreported. Without it
# parallel stays quiet and exits with the number of failed jobs. Test output is
# piped through sed to paint the [ERROR] lines red and the "passed" verdicts
# green; the remaining [INFO] lines (startup banners, skipped tests) stay plain.
set -o pipefail
parallel --will-cite 2>&1 << 'TESTS' \\
    | sed -u -e "s/^\\(\\[ERROR\\].*\\)\$/\${RED}\\1\${NC}/" \\
             -e "s/^\\(\\[INFO\\] Test .*passed.*\\)\$/\${GRN}\\1\${NC}/"
$TEST_LIST
TESTS
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
# ACD_JOBS sizes the inner simulation pool of test 21; empty means "use the
# test's default" (see _tests/21/test_analog_circuit_design.sh).
docker run -i --rm --name "$CONTAINER_NAME" --user "$(id -u):$(id -g)" -e DISPLAY= -e RAND="$RAND" \
    -e ACD_JOBS="${ACD_JOBS:-}" \
    -v "$PWD":"$WORKDIR":rw -v "$HOST_RUNDIR":"$RUNDIR":rw "$FULL_TAG" -s "$WORKDIR/$CMD"
RESULT=$?

# Cleanup (the run dir is kept for post-mortem analysis, remove it manually)
rm -f "$CMD"

exit $RESULT
