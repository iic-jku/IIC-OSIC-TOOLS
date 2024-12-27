#!/bin/bash

set -e

# Proxy setup for APT (auth with user/password does not work with add-apt-repository)
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
