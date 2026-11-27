# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile OpenROAD
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
FROM ${BASE_IMAGE_BUILD} AS openroad
ARG OPENROAD_REPO_URL="https://github.com/The-OpenROAD-Project/OpenROAD.git"
ARG OPENROAD_REPO_COMMIT="ae3cadce9bc13e3b2999ae9e3f1b1a17df3012f0"
ARG OPENROAD_NAME="openroad"
# The Bazel disk cache lives in a cache mount, outside the image layers, so a
# rebuild after a bump only compiles what changed. The nightly workflow carries
# the mount from one run to the next (tools/bazel_disk_cache.sh).
RUN --mount=type=bind,source=images/openroad,target=/images/openroad \
    --mount=type=cache,id=bazel-disk-cache-openroad,target=/bazel-disk-cache,sharing=shared \
    bash /images/openroad/scripts/install.sh
