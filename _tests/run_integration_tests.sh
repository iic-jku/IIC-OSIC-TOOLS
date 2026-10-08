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

# On a terminal, show one live progress line instead of the output of every
# test, and print only the failures. IIC_TEST_PROGRESS=0 keeps the plain
# per-test output, which is also what redirected output and CI logs get.
if [ -t 1 ] && [ "${IIC_TEST_PROGRESS:-1}" != 0 ]; then
    PROGRESS=1
else
    PROGRESS=0
fi

# The work dir and log of a passing test are deleted as soon as it finishes,
# so the run dir only holds what is needed to debug the failures. Set
# IIC_TEST_KEEP_PASSED=1 to keep everything.
if [ "${IIC_TEST_KEEP_PASSED:-0}" = 1 ]; then
    KEEP_PASSED=1
else
    KEEP_PASSED=0
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

# The bind-mounted source tree keeps its host label, which "container_t" may not
# access. See README section 5.1.1 and the start scripts.
if [[ "$OSTYPE" == "linux"* ]] && \
    { { command -v selinuxenabled > /dev/null 2>&1 && selinuxenabled; } || [ -f /sys/fs/selinux/enforce ]; }; then
    echo "[INFO] SELinux detected, adding --security-opt label=disable."
    ENGINE_EXTRA_PARAMS="${ENGINE_EXTRA_PARAMS} --security-opt label=disable"
fi

FULL_TAG=$1
# -v is required: hexdump collapses repeated identical output lines into a
# single "*", and "/1" makes every byte its own line -- so without it any two
# equal adjacent random bytes turn the run ID into something like "ad294d*" or
# even "b8*". That lands in the container name (which rejects "*"), in the run
# dir and in the name of the generated runner script. It hits about 1.8 % of
# runs, which is often enough to lose one.
RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
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
# Test 31 measured about 1800 s standalone (it does the same per-cell DRC/LVS/PEX
# work as 26, on 25 instead of 30 cells), so it is queued right next to it. Its
# runtime under contention is not measured yet.
# Test 32 runs the same kind of template regression as 20, on the
# ihp-sg13cmos5l sibling of that template, so it is queued right next to it.
# Test 35 measured 600 to 1200 s standalone (Magic PEX of four PDK benches), so
# it is queued after 31. Its runtime under contention is not measured yet.
SLOW_TESTS="28 26 31 35 24 20 32 21 01 10 07 18 22 19 04 15"

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
# run_integration_tests.sh) are based on. The progress line on the host reads
# it as well.
RUN=$RUNDIR/$RAND
JOBLOG=\$RUN/joblog.tsv
mkdir -p "\$RUN/logs"

# Every test logs to logs/<NN>_<test>.log, which the progress line on the host
# also uses to tell which tests are running. Without the progress line the
# output goes to stdout as well. A test writes only below \$RUN/<NN> (one test
# per directory), so a passing test is cleaned up by removing that dir.
run_one() {
    set -o pipefail
    local nn log rc
    nn=\$(basename "\$(dirname "\$1")")
    log=\$RUN/logs/\${nn}_\$(basename "\$1" .sh).log
    if [ ${PROGRESS} -eq 1 ]; then
        "\$1" > "\$log" 2>&1
    else
        "\$1" 2>&1 | tee "\$log"
    fi
    rc=\$?
    if [ \$rc -eq 0 ] && [ ${KEEP_PASSED} -ne 1 ]; then
        rm -rf "\${RUN:?}/\$nn" "\$log"
    fi
    return \$rc
}
export -f run_one
export RUN
export PARALLEL_SHELL=/bin/bash

set -o pipefail
parallel --will-cite --joblog "\$JOBLOG" run_one 2>&1 << 'TESTS' \\
    | sed -u -e "s/^\\(\\[ERROR\\].*\\)\$/\${RED}\\1\${NC}/" \\
             -e "s/^\\(\\[INFO\\] Test .*passed.*\\)\$/\${GRN}\\1\${NC}/"
$TEST_LIST
TESTS
RESULT=\$?
rmdir "\$RUN/logs" 2> /dev/null

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

run_container() {
    # ACD_JOBS sizes the inner simulation pool of test 21; empty means "use the
    # test's default" (see _tests/21/test_analog_circuit_design.sh).
    # shellcheck disable=SC2086
    ${CONTAINER_ENGINE} run -i --rm --name "$CONTAINER_NAME" --user "$(id -u):$(id -g)" -e DISPLAY= -e RAND="$RAND" \
        -e ACD_JOBS="${ACD_JOBS:-}" $ENGINE_EXTRA_PARAMS \
        -v "$PWD":"$WORKDIR":rw -v "$HOST_RUNDIR":"$RUNDIR":rw "$FULL_TAG" -s "$WORKDIR/$CMD"
}

# Redraw the progress line from the joblog and the logs dir, both visible on
# the host through the bind-mounted run dir. A test with a log but no joblog
# row is running. Failures are printed above the line once, with an excerpt.
HOST_RUN=$HOST_RUNDIR/$RAND
TOTAL=$(printf '%s\n' "$TEST_LIST" | wc -l | tr -d ' ')
REPORTED=0
FAILED=0
progress_update() {
    local n=0 cols fill bar running line
    # Count complete rows only (parallel may be writing the last one), minus
    # the header.
    if [ -f "$HOST_RUN/joblog.tsv" ]; then
        n=$(( $(wc -l < "$HOST_RUN/joblog.tsv") - 1 ))
        [ "$n" -lt 0 ] && n=0
    fi
    if [ "$n" -gt "$REPORTED" ]; then
        head -n $((n + 1)) "$HOST_RUN/joblog.tsv" | tail -n +$((REPORTED + 2)) \
            | awk -F'\t' '$7 != 0 || $8 != 0 {
                  k = split($NF, p, "/"); name = p[k]; sub(/\.sh$/, "", name)
                  why = ($8 != 0) ? "signal " $8 : "exit " $7
                  printf "%s/%s\t%s_%s.log\t%s, %.0f s\n", p[k-1], p[k], p[k-1], name, why, $4 }' \
            | while IFS=$'\t' read -r test log why; do
                  printf '\r\033[K%s[ERROR] %s FAILED (%s), log: %s%s\n' "$RED" "$test" "$why" "$HOST_RUN/logs/$log" "$NC"
                  { grep '^\[ERROR\]' "$HOST_RUN/logs/$log" || tail -n 5 "$HOST_RUN/logs/$log"; } 2> /dev/null \
                      | tail -n 5 | sed 's/^/        > /'
              done
        FAILED=$(head -n $((n + 1)) "$HOST_RUN/joblog.tsv" | awk -F'\t' 'NR > 1 && ($7 != 0 || $8 != 0)' | wc -l | tr -d ' ')
        REPORTED=$n
    fi
    running=$(
        {
            head -n $((n + 1)) "$HOST_RUN/joblog.tsv" 2> /dev/null \
                | awk -F'\t' 'NR > 1 { k = split($NF, p, "/"); sub(/\.sh$/, "", p[k]); print "D " p[k-1] "_" p[k] }'
            # shellcheck disable=SC2012  # log names are generated, plain ASCII
            ls "$HOST_RUN/logs" 2> /dev/null | sed -e 's/\.log$//' -e 's/^/L /'
        } | awk '$1 == "D" { done[$2] = 1; next } !($2 in done) { split($2, q, "_"); printf "%s ", q[1] }'
    )
    cols=$(stty size < /dev/tty 2> /dev/null | awk '{ print $2 }')
    # A pty without a size reports 0 columns.
    if [ -z "$cols" ] || [ "$cols" -lt 2 ]; then
        cols=80
    fi
    fill=$((n * 30 / TOTAL))
    bar=$(printf '%*s' "$fill" '' | tr ' ' '#')$(printf '%*s' $((30 - fill)) '' | tr ' ' '.')
    line=$(printf '[%s] %d/%d  %d failed  %02d:%02d:%02d' "$bar" "$n" "$TOTAL" "$FAILED" \
        $((SECONDS / 3600)) $((SECONDS % 3600 / 60)) $((SECONDS % 60)))
    [ -n "$running" ] && line="$line  running: $running"
    # A wrapped line cannot be redrawn with \r, so cut it to the terminal width.
    line=${line:0:$((cols - 1))}
    [ "$FAILED" -gt 0 ] && line=${line/"$FAILED failed"/"${RED}$FAILED failed${NC}"}
    printf '\r\033[K%s' "$line"
}

# Now run the actual tests
echo "[INFO] Test output of this run: $HOST_RUN (inside the container: $RUNDIR/$RAND)"
if [ $KEEP_PASSED -eq 0 ]; then
    echo "[INFO] Only failed tests keep their data, set IIC_TEST_KEEP_PASSED=1 to keep all."
fi
if [ $PROGRESS -eq 1 ]; then
    # The container runs in the background, where it ignores Ctrl-C, so stop
    # it explicitly. Its own output (parallel messages and the final summary)
    # goes to runner.log and is shown when it is done.
    mkdir -p "$HOST_RUN"
    trap 'printf "\n%s\n" "${RED}[ERROR] Interrupted, stopping container $CONTAINER_NAME.${NC}"
          ${CONTAINER_ENGINE} kill "$CONTAINER_NAME" > /dev/null 2>&1
          rm -f "$CMD"
          exit 130' INT TERM
    SECONDS=0
    run_container > "$HOST_RUN/runner.log" 2>&1 &
    PID=$!
    while kill -0 "$PID" 2> /dev/null; do
        progress_update
        sleep 2
    done
    wait "$PID"
    RESULT=$?
    progress_update
    printf '\n'
    trap - INT TERM
    # Skip the startup banner of the container, unless it failed before
    # getting to the tests.
    awk 'FNR == NR { if (/^\[INFO\] Executing command:/) skip = FNR; next } FNR > skip' \
        "$HOST_RUN/runner.log" "$HOST_RUN/runner.log"
else
    run_container
    RESULT=$?
fi

# Cleanup (the run dir is kept for post-mortem analysis, remove it manually)
rm -f "$CMD"

exit $RESULT
