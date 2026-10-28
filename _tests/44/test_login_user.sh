#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Test that a login shell started like a docker exec sets USER to a single name.
#
# The entrypoint gives a UID without a passwd entry (docker run --user UID:GID) a fake one through nss_wrapper, but a docker exec into the running container does not inherit it.
# There the profile set USER to the two lines "1000" and "designer", which then ended up in getpass.getuser() and in file names built from it (pytest's tmp_path, for one).
# The login shell is therefore started without USER and without the nss_wrapper variables, as a docker exec gets it.

DEBUG=${DEBUG:-0}

ERROR=0

# IIC_OSIC_TOOLS_QUIET keeps the profile's [INFO] lines out of the captured output.
EXEC_ENV=(env -u USER -u LD_PRELOAD -u NSS_WRAPPER_PASSWD -u NSS_WRAPPER_GROUP IIC_OSIC_TOOLS_QUIET=1)
VALUE=$("${EXEC_ENV[@]}" bash -lc 'printf "%s" "$USER"')
GETPASS=$("${EXEC_ENV[@]}" bash -lc 'python3 -c "import getpass; print(getpass.getuser(), end=\"\")"')

if [ -z "$VALUE" ]; then
    echo "[ERROR] A login shell leaves USER empty."
    ERROR=1
elif [[ "$VALUE" == *$'\n'* ]]; then
    echo "[ERROR] A login shell sets USER to more than one line: $(printf "%q" "$VALUE")"
    ERROR=1
elif [ "$GETPASS" != "$VALUE" ]; then
    echo "[ERROR] getpass.getuser() returns $(printf "%q" "$GETPASS"), USER is $(printf "%q" "$VALUE")."
    ERROR=1
elif [ "$DEBUG" = "1" ]; then
    echo "[INFO] A login shell sets USER to $VALUE (uid $(id -u))."
fi

if [ $ERROR -eq 1 ]; then
    echo "[ERROR] Test <USER in a login shell> FAILED."
    exit 1
else
    echo "[INFO] Test <USER in a login shell> passed."
    exit 0
fi
