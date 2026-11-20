# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile different components for the rftoolkit
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS rftoolkit
ARG RFTK_NAME="rftoolkit"
ARG RFTK_FASTHENRY_REPO_URL="https://github.com/ediloren/FastHenry2.git"
ARG RFTK_FASTHENRY_REPO_COMMIT="363e43ed57ad3b9affa11cba5a86624fad0edaa9"
ARG RFTK_FASTERCAP_REPO_URL="https://github.com/iic-jku/FasterCap.git"
ARG RFTK_FASTERCAP_REPO_COMMIT="v6.4.0"
ARG RFTK_LINALGEBRA_REPO_URL="https://github.com/iic-jku/LinAlgebra.git"
ARG RFTK_LINALGEBRA_REPO_COMMIT="4da8bf29cb004239ba8152bd6afd4b1f7e8a2821"
ARG RFTK_GEOMETRY_REPO_URL="https://github.com/iic-jku/Geometry.git"
ARG RFTK_GEOMETRY_REPO_COMMIT="426c1970ab71a4a1cf75bc15ff55d28b6281dde6"
RUN --mount=type=bind,source=images/rftoolkit,target=/images/rftoolkit \
    bash /images/rftoolkit/scripts/install.sh
