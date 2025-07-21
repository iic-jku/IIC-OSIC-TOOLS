#######################################################################
# Compile surfer
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS surfer
ARG SURFER_REPO_URL="https://gitlab.com/surfer-project/surfer.git"
ARG SURFER_REPO_COMMIT="v0.3.0"
ARG SURFER_NAME="surfer"
USER 0:0
RUN --mount=type=bind,source=images/surfer,target=/images/surfer \
    bash /images/surfer/scripts/install.sh
