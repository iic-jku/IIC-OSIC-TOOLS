#!/bin/bash
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test if sak-job.py starts long commands detached and reports their status, waits for them, shows their log,
# cancels them including their children, flags a job without supervisor as lost and rejects unknown IDs.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}

ERROR=0
WORKDIR=${RUNS_DIR}/${RAND}/57
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1

# a failing test must not leave the sleeping jobs behind
cleanup() {
    local pidfile pid
    for pidfile in "$WORKDIR"/.sak-jobs/*/pid; do
        [ -f "$(dirname "$pidfile")/cmd.json" ] || continue
        pid=$(cat "$pidfile" 2> /dev/null)
        [ -n "$pid" ] && kill -KILL -- "-$pid" 2> /dev/null
    done
    return 0
}
trap cleanup EXIT

JOB() { sak-job.py -w "$WORKDIR" --json "$@" 2> "$WORKDIR/stderr.txt"; }

# check <name> <expected exit> <python assertion on d> <sak-job.py args...>, the ID of the last call is in $ID
OUT=""
check() {
    local name=$1 want=$2 assertion=$3 rc
    shift 3
    OUT=$(JOB "$@")
    rc=$?
    if [ $rc -ne "$want" ]; then
        echo "[ERROR] $name: exit code $rc, expected $want"
        [ -n "$DEBUG" ] && { echo "$OUT"; cat "$WORKDIR/stderr.txt"; }
        ERROR=1
        return
    fi
    if [ -n "$assertion" ]; then
        if ! printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['schema']==1 and d['tool']=='sak-job'; $assertion" 2> "$WORKDIR/assert.txt"; then
            echo "[ERROR] $name: field check failed: $assertion"
            [ -n "$DEBUG" ] && { echo "$OUT"; cat "$WORKDIR/assert.txt"; }
            ERROR=1
        fi
    fi
}
id_of() { printf '%s' "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])"; }

# 1: success with output
check "start hello" 0 "d['state']=='running'" start -- sh -c 'echo hello; sleep 2'
ID1=$(id_of)
check "wait hello" 0 "d['state']=='done' and d['rc']==0 and d['log_tail']==['hello'] and d['elapsed_s']>=2 and d['end'] is not None" wait "$ID1" --timeout 30
check "status hello" 0 "d['state']=='done'" status "$ID1"
if [ "$(sak-job.py -w "$WORKDIR" tail "$ID1" -n 1 2> /dev/null)" != "hello" ]; then
    echo "[ERROR] tail -n 1 of the first job did not print hello"
    ERROR=1
fi
check "tail json" 0 "d['lines']==['hello']" tail "$ID1"

# 2: failure
check "start false" 0 "" start -- false
ID2=$(id_of)
check "wait false" 1 "d['state']=='failed' and d['rc']==1" wait "$ID2" --timeout 30

# 3: running, timeout, cancel
check "start sleep" 0 "" start -- sleep 300
ID3=$(id_of)
check "wait timeout" 4 "d['state']=='running' and d['end'] is None" wait "$ID3" --timeout 1
check "status running" 4 "d['state']=='running'" status "$ID3"
check "cancel" 0 "d['state']=='cancelled'" cancel "$ID3"
check "status cancelled" 1 "d['state']=='cancelled'" status "$ID3"

# 4: cancel takes the children along
check "start children" 0 "" start -- sh -c 'sleep 300 & sleep 300'
ID4=$(id_of)
PGID=$(cat "$WORKDIR/.sak-jobs/$ID4/pid")
if ! kill -0 -- "-$PGID" 2> /dev/null; then
    echo "[ERROR] process group $PGID of the supervisor does not exist"
    ERROR=1
fi
check "cancel children" 0 "d['state']=='cancelled'" cancel "$ID4"
GONE=0
for _ in $(seq 1 20); do
    if ! kill -0 -- "-$PGID" 2> /dev/null; then
        GONE=1
        break
    fi
    sleep 0.5
done
if [ $GONE -ne 1 ]; then
    echo "[ERROR] processes of group $PGID are still alive 10 s after cancel"
    ERROR=1
fi

# 5: a command that does not exist
check "start missing command" 0 "" start -- /no/such/command
ID5=$(id_of)
check "wait missing command" 1 "d['state']=='failed' and d['rc']==127" wait "$ID5" --timeout 30

# 6: name of the job
check "start named" 0 "d['id'].startswith('flow-')" start -n flow -- true
ID6=$(id_of)
check "wait named" 0 "d['state']=='done'" wait "$ID6" --timeout 30

# 7: unknown ID
for sub in status wait tail cancel; do
    check "$sub unknown id" 2 "d['status']=='error'" $sub nope
done

# 8: list
check "list" 0 "len(d['jobs'])==6 and all('log_tail' not in j for j in d['jobs'])" list

# 9: usage error
check "usage" 3 "d['status']=='error'" bogus

# 10: a job outlives the shell that started it
sh -c 'sak-job.py -w "$0" --json start -- sleep 3' "$WORKDIR" > "$WORKDIR/detached.json" 2> /dev/null
ID7=$(python3 -c "import json; print(json.load(open('$WORKDIR/detached.json'))['id'])")
check "wait detached" 0 "d['state']=='done' and d['elapsed_s']>=3" wait "$ID7" --timeout 30

# 11: a job folder with a pid file but neither rc nor a held lock
mkdir -p "$WORKDIR/.sak-jobs/lostjob-20260101-000000-0000"
echo 4194300 > "$WORKDIR/.sak-jobs/lostjob-20260101-000000-0000/pid"
check "lost" 2 "d['state']=='lost'" status lostjob-20260101-000000-0000

# 12: cancel of a command that ignores SIGTERM (SIGKILL path), a concurrent wait must never see "lost"
check "start ignoring term" 0 "" start -- sh -c 'trap "" TERM; sleep 300'
ID8=$(id_of)
sleep 1
JOB wait "$ID8" --timeout 30 > "$WORKDIR/wait8.json" &
WPID=$!
sleep 1
check "cancel ignoring term" 0 "d['state']=='cancelled'" cancel "$ID8"
wait $WPID
RC=$?
if [ $RC -ne 1 ] || ! python3 -c "import json; assert json.load(open('$WORKDIR/wait8.json'))['state']=='cancelled'"; then
    echo "[ERROR] concurrent wait during cancel: exit code $RC, expected 1 with state cancelled"
    ERROR=1
fi

# 13: two cancels of one job at the same time
check "start double cancel" 0 "" start -- sleep 300
ID9=$(id_of)
JOB cancel "$ID9" > "$WORKDIR/c1.json" &
P1=$!
JOB cancel "$ID9" > "$WORKDIR/c2.json" &
P2=$!
wait $P1; RC1=$?
wait $P2; RC2=$?
if [ $RC1 -ne 0 ] || [ $RC2 -ne 0 ]; then
    echo "[ERROR] concurrent cancels exited with $RC1 and $RC2, expected 0 and 0"
    ERROR=1
fi
check "status double cancel" 1 "d['state']=='cancelled'" status "$ID9"

# 14: the command runs where the caller stands, not in the -w folder
mkdir -p "$WORKDIR/elsewhere"
OUT=$(cd "$WORKDIR/elsewhere" && JOB start -- pwd)
ID10=$(id_of)
check "wait pwd" 0 "d['state']=='done' and d['log_tail']==['$WORKDIR/elsewhere']" wait "$ID10" --timeout 30

# 15: the command starts with default signal dispositions
check "start hup" 0 "" start -- python3 -c "import signal; print(signal.getsignal(signal.SIGHUP) == signal.SIG_DFL)"
ID11=$(id_of)
check "wait hup" 0 "d['log_tail']==['True']" wait "$ID11" --timeout 30

# without --json: text, no JSON
TXT=$(sak-job.py -w "$WORKDIR" status "$ID1" 2> /dev/null)
RC=$?
if [ $RC -ne 0 ] || printf '%s' "$TXT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2> /dev/null \
    || ! printf '%s' "$TXT" | grep -q 'done'; then
    echo "[ERROR] text output of status is wrong (exit code $RC)"
    ERROR=1
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <sak-job detached jobs> FAILED."
    exit 1
else
    echo "[INFO] Test <sak-job detached jobs> passed."
    exit 0
fi
