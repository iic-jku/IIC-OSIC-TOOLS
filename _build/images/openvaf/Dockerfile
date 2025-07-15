#######################################################################
# Compile openvaf-reloaded
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS openvaf
ARG OPENVAF_REPO_URL="https://github.com/arpadbuermen/OpenVAF.git"
ARG OPENVAF_REPO_COMMIT="643fcead0564aa915761257c08bd7f92c7634639"
ARG OPENVAF_NAME="openvaf"
ENV OPENVAF_NAME=${OPENVAF_NAME}
USER 0:0
RUN --mount=type=bind,source=images/openvaf,target=/images/openvaf \
    bash /images/openvaf/scripts/install.sh
