# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile xschem
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS xschem
ARG XSCHEM_REPO_URL="https://github.com/StefanSchippers/xschem.git"
ARG XSCHEM_REPO_COMMIT="c8b26a17d8d53ce7fbd9e7d45ab6bb03e75996e0"
ARG XSCHEM_NAME="xschem"
RUN --mount=type=bind,source=images/xschem,target=/images/xschem \
    bash /images/xschem/scripts/install.sh
