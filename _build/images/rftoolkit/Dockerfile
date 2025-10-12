#######################################################################
# Compile different components for the rftoolkit
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS rftoolkit
ARG RFTK_NAME="rftoolkit"
ARG RFTK_FASTHENRY_REPO_URL="https://github.com/ediloren/FastHenry2.git"
ARG RFTK_FASTHENRY_REPO_COMMIT="363e43ed57ad3b9affa11cba5a86624fad0edaa9"
ARG RFTK_FASTERCAP_REPO_URL="https://github.com/ediloren/FasterCap.git"
ARG RFTK_FASTERCAP_REPO_COMMIT="b42179a8fdd25ab42fe45527282b4a738d7e7f87"
RUN --mount=type=bind,source=images/rftoolkit,target=/images/rftoolkit \
    bash /images/rftoolkit/scripts/install.sh
