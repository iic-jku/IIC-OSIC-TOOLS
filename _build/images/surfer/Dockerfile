#######################################################################
# Compile surfer
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS surfer
ARG SURFER_REPO_URL="https://gitlab.com/surfer-project/surfer.git"
ARG SURFER_REPO_COMMIT="v0.5.0"
ARG SURFER_NAME="surfer"
RUN --mount=type=bind,source=images/surfer,target=/images/surfer \
    bash /images/surfer/scripts/install.sh
