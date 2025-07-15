#######################################################################
# Compile nvc (VHDL simulator)
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS nvc
ARG NVC_REPO_URL="https://github.com/nickg/nvc.git"
ARG NVC_REPO_COMMIT="r1.16.2"
ARG NVC_NAME="nvc"
USER 0:0
RUN --mount=type=bind,source=images/nvc,target=/images/nvc \
    bash /images/nvc/scripts/install.sh
