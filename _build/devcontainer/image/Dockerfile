# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

ARG VERSION="latest"
FROM hpretl/iic-osic-tools:${VERSION}
USER root
RUN useradd -m -s /bin/bash -G sudo designer
USER designer
