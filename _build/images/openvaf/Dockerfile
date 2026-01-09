#######################################################################
# Compile openvaf-reloaded
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS openvaf
ARG OPENVAF_REPO_URL="https://github.com/arpadbuermen/OpenVAF.git"
ARG OPENVAF_REPO_COMMIT="75df7b362e945c7cb49b791879ff4b3f6a9b13b1"
ARG OPENVAF_NAME="openvaf"
ENV OPENVAF_NAME=${OPENVAF_NAME}
RUN --mount=type=bind,source=images/openvaf,target=/images/openvaf \
    bash /images/openvaf/scripts/install.sh
