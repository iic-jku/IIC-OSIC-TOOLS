#######################################################################
# Compile irsim
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS irsim
ARG IRSIM_REPO_URL="https://github.com/rtimothyedwards/irsim.git"
ARG IRSIM_REPO_COMMIT="037a1b97086ef8425bdd9379e38f6aada4f327e7"
ARG IRSIM_NAME="irsim"
RUN --mount=type=bind,source=images/irsim,target=/images/irsim \
    bash /images/irsim/scripts/install.sh
