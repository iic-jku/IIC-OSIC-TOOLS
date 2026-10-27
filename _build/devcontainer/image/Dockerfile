# SPDX-FileCopyrightText: 2022-2026 Harald Pretl and Georg Zachl
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0

ARG VERSION="latest"
FROM hpretl/iic-osic-tools:${VERSION}
USER root
# designer gets no password, so sudo must not ask for one (issue #389)
RUN useradd -m -s /bin/bash -G sudo designer && \
    echo 'designer ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/designer && \
    chmod 0440 /etc/sudoers.d/designer
USER designer
