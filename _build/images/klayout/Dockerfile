#######################################################################
# Compile klayout
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS klayout
ARG KLAYOUT_REPO_URL="https://github.com/KLayout/klayout.git"
ARG KLAYOUT_REPO_COMMIT="v0.30.2"
ARG KLAYOUT_NAME="klayout"
USER 0:0
RUN --mount=type=bind,source=images/klayout,target=/images/klayout \
    bash /images/klayout/scripts/install.sh
