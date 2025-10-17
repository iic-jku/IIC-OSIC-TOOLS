#######################################################################
# Compile klayout
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS klayout
ARG KLAYOUT_REPO_URL="https://github.com/KLayout/klayout.git"
ARG KLAYOUT_REPO_COMMIT="v0.30.4-1"
ARG KLAYOUT_NAME="klayout"
RUN --mount=type=bind,source=images/klayout,target=/images/klayout \
    bash /images/klayout/scripts/install.sh
