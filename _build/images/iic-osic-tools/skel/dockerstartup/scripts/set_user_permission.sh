#!/usr/bin/env bash
### every exit != 0 fails the script
set -e
if [[ -n $DEBUG ]]; then
    verbose="-v"
fi

for var in "$@"
do
    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Fix permissions for: $var"
    # shellcheck disable=SC2086
    find "$var"/ -name '*.sh' -exec chmod $verbose a+x {} +
    # shellcheck disable=SC2086
    find "$var"/ -name '*.desktop' -exec chmod $verbose a+x {} +
    # shellcheck disable=SC2086
    chgrp -R 0 "$var" && chmod -R $verbose a+rw "$var" && find "$var" -type d -exec chmod $verbose a+x {} +
done
