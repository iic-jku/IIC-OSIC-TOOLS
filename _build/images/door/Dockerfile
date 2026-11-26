# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile door
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS door
ARG DOOR_REPO_URL="https://github.com/IHP-GmbH/Door.git"
ARG DOOR_REPO_COMMIT="102f605665bbc7e289a5cfdfbb36c5838b9b4b2e"
ARG DOOR_NAME="door"
RUN --mount=type=bind,source=images/door,target=/images/door \
    bash /images/door/scripts/install.sh
