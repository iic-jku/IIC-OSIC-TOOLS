# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#######################################################################
# Compile OpenCDC (static clock domain crossing checker)
#######################################################################
ARG BASE_IMAGE_BUILD="registry.iic.jku.at:5000/iic-osic-tools:base-dev"
ARG TOOL_IMAGE_SLANG="registry.iic.jku.at:5000/iic-osic-tools:tool-slang-latest"

FROM ${TOOL_IMAGE_SLANG} AS slang
FROM ${BASE_IMAGE_BUILD} AS opencdc

ARG OPENCDC_REPO_URL="https://github.com/Ayoubbelguellaoui/CDC.git"
ARG OPENCDC_REPO_COMMIT="6c6bd44bf2d137e108437bb5a9729c8fd5350886"
ARG OPENCDC_NAME="opencdc"

COPY --from=slang	${TOOLS}/slang    ${TOOLS}/slang

RUN --mount=type=bind,source=images/opencdc,target=/images/opencdc \
    bash /images/opencdc/scripts/install.sh
