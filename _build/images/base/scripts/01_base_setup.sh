#!/bin/bash
# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

set -e

# Proxy setup for GIT
_proxy_detected () {
    if [[ ${http_proxy:-"unset"} != "unset" || ${https_proxy:-"unset"} != "unset" ]]; then
        return 0
    else
        return 1
    fi
}

# Enable proxy auth for GIT
if _proxy_detected; then
    git config --global http.proxyAuthMethod 'basic'
    git config --global http.sslVerify "false"
fi

echo "[INFO] Cleaning up caches"
rm -rf /tmp/*
