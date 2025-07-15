#######################################################################
# Compile irsim
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS irsim
ARG IRSIM_REPO_URL="https://github.com/rtimothyedwards/irsim.git"
ARG IRSIM_REPO_COMMIT="34b1e7bbb1014346a5bbe9171bd25840ee020578"
ARG IRSIM_NAME="irsim"
USER 0:0
RUN --mount=type=bind,source=images/irsim,target=/images/irsim \
    bash /images/irsim/scripts/install.sh
