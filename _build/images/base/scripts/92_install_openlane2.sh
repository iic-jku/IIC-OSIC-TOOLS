#!/bin/bash

set -e

# Need to compile OpenLane2 manually, as otherwise
# version clash on KLayout
cd /tmp
git clone --depth=1 https://github.com/iic-jku/openlane2.git
cd openlane2 || exit 1
pip install --no-cache-dir --break-system-packages .
