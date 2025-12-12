#######################################################################
# Compile openvaf-reloaded
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS openvaf
ARG OPENVAF_REPO_URL="https://github.com/arpadbuermen/OpenVAF.git"
ARG OPENVAF_REPO_COMMIT="2f8ec9908b6eb17033587f3b35abeaa9c8997a77"
ARG OPENVAF_NAME="openvaf"
ENV OPENVAF_NAME=${OPENVAF_NAME}
RUN --mount=type=bind,source=images/openvaf,target=/images/openvaf \
    bash /images/openvaf/scripts/install.sh
