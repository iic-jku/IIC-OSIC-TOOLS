#######################################################################
# Compile kactus2
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS kactus2
ARG KACTUS_REPO_URL="https://github.com/kactus2/kactus2dev.git"
ARG KACTUS_REPO_COMMIT="v3.13.5"
ARG KACTUS_NAME="kactus2"
RUN --mount=type=bind,source=images/kactus2,target=/images/kactus2 \
    bash /images/kactus2/scripts/install.sh
