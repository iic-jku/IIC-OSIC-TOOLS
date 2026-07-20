#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
# Set current user in nss_wrapper

USER_ID=$(id -u)
GROUP_ID=$(id -g)
[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] USER_ID: $USER_ID, GROUP_ID: $GROUP_ID"

if [[ "$USER_ID" != "0" ]]; then
    if [ -z "${HOME}" ]; then
        echo "[ERROR] HOME is not set; cannot generate nss_wrapper passwd entry."
        return 1 2>/dev/null || exit 1
    fi

    NSS_WRAPPER_PASSWD=/tmp/passwd
    NSS_WRAPPER_GROUP=/tmp/group

    # Use install(1) to avoid following pre-existing symlinks in /tmp.
    if ! install -m 0644 /etc/passwd "$NSS_WRAPPER_PASSWD" \
        || ! install -m 0644 /etc/group "$NSS_WRAPPER_GROUP"; then
        echo "[ERROR] Failed to create nss_wrapper passwd/group files."
        return 1 2>/dev/null || exit 1
    fi

    # Guard against duplicate entries when this script is sourced more than once.
    if ! grep -q "^designer:" "$NSS_WRAPPER_PASSWD"; then
        echo "designer:x:${USER_ID}:${GROUP_ID}:Default Application User:${HOME}:/bin/bash" >> "$NSS_WRAPPER_PASSWD"
    fi
    if ! grep -q "^designers:" "$NSS_WRAPPER_GROUP"; then
        # 4th field of /etc/group is a comma-separated list of *usernames*, not UIDs.
        echo "designers:x:${GROUP_ID}:designer" >> "$NSS_WRAPPER_GROUP"
    fi

    export NSS_WRAPPER_PASSWD
    export NSS_WRAPPER_GROUP

    if [ -r /usr/lib/libnss_wrapper.so ]; then
        NSS_WRAPPER_LIB=/usr/lib/libnss_wrapper.so
    elif [ -r /usr/lib64/libnss_wrapper.so ]; then
        NSS_WRAPPER_LIB=/usr/lib64/libnss_wrapper.so
    elif [ -r /usr/lib/x86_64-linux-gnu/libnss_wrapper.so ]; then
        NSS_WRAPPER_LIB=/usr/lib/x86_64-linux-gnu/libnss_wrapper.so
    elif [ -r /usr/lib/aarch64-linux-gnu/libnss_wrapper.so ]; then
        NSS_WRAPPER_LIB=/usr/lib/aarch64-linux-gnu/libnss_wrapper.so
    else
        echo "[ERROR] No libnss_wrapper.so installed!"
        return 1 2>/dev/null || exit 1
    fi

    # Prepend to LD_PRELOAD; preserve any value already set by the caller.
    export LD_PRELOAD="${NSS_WRAPPER_LIB}${LD_PRELOAD:+ $LD_PRELOAD}"
    export USER=designer
fi
