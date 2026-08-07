#!/bin/bash
# SPDX-FileCopyrightText: 2024-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Run all tests (checks) in the subdirectories using a specified container image.

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

# Select the container engine (Podman or Docker), can be overridden by setting
# CONTAINER_ENGINE. Unlike the start scripts, Podman is preferred here when both
# are installed: a test run needs no daemon and is happy rootless.
if [ -z ${CONTAINER_ENGINE+z} ]; then
    if command -v podman > /dev/null 2>&1; then
        CONTAINER_ENGINE="podman"
    elif command -v docker > /dev/null 2>&1; then
        CONTAINER_ENGINE="docker"
    else
        echo "${RED}[ERROR] No container engine found, please install Podman or Docker!${NC}"
        exit 1
    fi
    echo "[INFO] Container engine auto-set to ${CONTAINER_ENGINE}."
fi

if ! command -v "${CONTAINER_ENGINE}" > /dev/null 2>&1; then
    echo "${RED}[ERROR] Container engine <${CONTAINER_ENGINE}> not found!${NC}"
    exit 1
fi

# Detect Podman, and Podman rootless mode on Linux (the docker CLI can also be
# the podman-docker alias, so check the version string). Only Linux needs
# --userns=keep-id: there the container user would otherwise be mapped to a
# subuid that cannot write the bind-mounted source tree and run dir. On macOS
# the podman machine already maps the host user, and adding keep-id there only
# costs an ID-shifting pass over the (large) image.
ENGINE_EXTRA_PARAMS=""
if ${CONTAINER_ENGINE} --version 2>/dev/null | grep -qi "podman"; then
    if [[ "$OSTYPE" == "linux"* ]] && \
        ${CONTAINER_ENGINE} info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -qi "true"; then
        echo "[INFO] Podman rootless mode detected, adding --userns=keep-id."
        ENGINE_EXTRA_PARAMS="--userns=keep-id"
    fi
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
# outdated entry costs some wall clock but never breaks the run.
#
# Order taken from a full run of hpretl/iic-osic-tools:next on 9 cores (the
# per-test runtimes of every run are in the joblog, see below):
#
#   28: 4356 s   26: 1465 s   24:  932 s   20:  756 s   21:  555 s
#   01:  382 s   10:  377 s   07:  366 s   18:  305 s   22:  286 s
#   19:  270 s   04:  269 s   15:  188 s   ... rest below 150 s
#
# Test 28 alone defines the wall clock of the whole suite, so it must start
# first. Note these are runtimes *under full contention*; standalone they are
# considerably shorter (21: 108 s, 27: 78 s).
SLOW_TESTS="28 26 24 20 21 01 10 07 18 22 19 04 15"

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

# Check if newer image is available and pull if needed. Set IIC_TEST_NO_PULL=1
# when testing a locally built image: the pull would replace it with the one
# from the registry that carries the same tag.
if [ "${IIC_TEST_NO_PULL:-0}" = 1 ]; then
    echo "[INFO] IIC_TEST_NO_PULL=1, testing the local image $FULL_TAG without pulling."
else
    ${CONTAINER_ENGINE} pull --quiet "$FULL_TAG" > /dev/null
fi

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

# The test list is assembled by run_integration_tests.sh and inlined below,
# ordered longest-running first so the job pool does not end up waiting for a
# long test that started last.
#
# No --halt: it made GNU parallel announce every failed job and the shutdown of
# its job pool, and it silently left the remaining tests unreported. Without it
# parallel stays quiet and exits with the number of failed jobs. Test output is
# piped through sed to paint the [ERROR] lines red and the "passed" verdicts
# green; the remaining [INFO] lines (startup banners, skipped tests) stay plain.
#
# --joblog records start time, runtime and exit status of every test, which is
# what the per-test timings at the end of the run (and the SLOW_TESTS order in
# run_integration_tests.sh) are based on.
JOBLOG=$RUNDIR/$RAND/joblog.tsv
mkdir -p "\$(dirname "\$JOBLOG")"
set -o pipefail
parallel --will-cite --joblog "\$JOBLOG" 2>&1 << 'TESTS' \\
    | sed -u -e "s/^\\(\\[ERROR\\].*\\)\$/\${RED}\\1\${NC}/" \\
             -e "s/^\\(\\[INFO\\] Test .*passed.*\\)\$/\${GRN}\\1\${NC}/"
$TEST_LIST
TESTS
RESULT=\$?

# Runtime of the five slowest tests, so the SLOW_TESTS order can be kept honest
# (the full table is in \$JOBLOG).
if [ -s "\$JOBLOG" ]; then
    echo "[INFO] Slowest tests of this run (see \$JOBLOG for all of them):"
    tail -n +2 "\$JOBLOG" | sort -t\$'\t' -k4,4 -rn | head -5 \\
        | awk -F'\t' '{ n = split(\$NF, p, "/"); printf "[INFO]   %6.0f s  %s/%s\n", \$4, p[n-1], p[n] }'
fi

if [ \$RESULT -ne 0 ]; then
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
# shellcheck disable=SC2086
${CONTAINER_ENGINE} run -i --rm --name "$CONTAINER_NAME" --user "$(id -u):$(id -g)" -e DISPLAY= -e RAND="$RAND" \
    -e ACD_JOBS="${ACD_JOBS:-}" $ENGINE_EXTRA_PARAMS \
    -v "$PWD":"$WORKDIR":rw -v "$HOST_RUNDIR":"$RUNDIR":rw "$FULL_TAG" -s "$WORKDIR/$CMD"
RESULT=$?

# Cleanup (the run dir is kept for post-mortem analysis, remove it manually)
rm -f "$CMD"

exit $RESULT
