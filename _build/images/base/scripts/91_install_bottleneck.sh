#!/bin/bash

set -e

# Need to compile Bottleneck manually, as otherwise
# error in gdsfactory and scikit-rf on aarch64
cd /tmp
git clone --depth=1 https://github.com/pydata/bottleneck.git
cd bottleneck || exit 1
pip install --no-cache-dir --break-system-packages .
