#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
### every exit != 0 fails the script
set -e

# -v only when DEBUG is set; safe under `set -u`
verbose="${DEBUG:+-v}"

for var in "$@"
do
    if [ ! -d "$var" ]; then
        echo "[WARN] Skipping non-directory: $var"
        continue
    fi

    [ -z "${IIC_OSIC_TOOLS_QUIET}" ] && echo "[INFO] Fix permissions for: $var"

    # Only act on regular files / directories; never follow symlinks (would
    # otherwise modify permissions/ownership outside of "$var").
    # shellcheck disable=SC2086
    find "$var" -type f -name '*.sh'      -exec chmod $verbose a+x {} +
    # shellcheck disable=SC2086
    find "$var" -type f -name '*.desktop' -exec chmod $verbose a+x {} +

    # chgrp -h on symlinks themselves, recurse without following links.
    find "$var" \( -type f -o -type d -o -type l \) -exec chgrp $verbose -h 0 {} +

    # shellcheck disable=SC2086
    find "$var" -type d -exec chmod $verbose a+rwx {} +
    # shellcheck disable=SC2086
    find "$var" -type f -exec chmod $verbose a+rw  {} +
done
