#######################################################################
# Compile cvc_rv
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS cvc_rv
ARG CVC_RV_REPO_URL="https://github.com/d-m-bailey/cvc.git"
ARG CVC_RV_REPO_COMMIT="4dbffb7271f048ced9aed0aad58313fefc888a1a"
ARG CVC_RV_NAME="cvc_rv"
RUN --mount=type=bind,source=images/cvc_rv,target=/images/cvc_rv \
    bash /images/cvc_rv/scripts/install.sh
