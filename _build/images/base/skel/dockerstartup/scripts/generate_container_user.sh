#!/bin/bash
# Set current user in nss_wrapper

USER_ID=$(id -u)
GROUP_ID=$(id -g)
[ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] USER_ID: $USER_ID, GROUP_ID: $GROUP_ID"

if [ x"$USER_ID" != x"0" ]; then
    NSS_WRAPPER_PASSWD=/tmp/passwd
    NSS_WRAPPER_GROUP=/tmp/group

    cat /etc/passwd > $NSS_WRAPPER_PASSWD
    cat /etc/group  > $NSS_WRAPPER_GROUP

    echo "designer:x:${USER_ID}:${GROUP_ID}:Default Application User:${HOME}:/bin/bash" >> $NSS_WRAPPER_PASSWD
    echo "designers:x:${GROUP_ID}:${USER_ID}" >> $NSS_WRAPPER_GROUP

    export NSS_WRAPPER_PASSWD
    export NSS_WRAPPER_GROUP

    if [ -r /usr/lib/libnss_wrapper.so ]; then
        LD_PRELOAD=/usr/lib/libnss_wrapper.so
    elif [ -r /usr/lib64/libnss_wrapper.so ]; then
        LD_PRELOAD=/usr/lib64/libnss_wrapper.so
    elif [ -r /usr/lib/x86_64-linux-gnu/libnss_wrapper.so ]; then
        LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libnss_wrapper.so
    elif [ -r /usr/lib/aarch64-linux-gnu/libnss_wrapper.so ]; then
        LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libnss_wrapper.so
    else
        echo "[ERROR] No libnss_wrapper.so installed!"
        exit 1
    fi
    export LD_PRELOAD
    export USER=designer
fi
