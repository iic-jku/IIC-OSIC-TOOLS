#######################################################################
# Compile cvc_rv
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base
FROM ${BASE_IMAGE_BUILD} AS cvc_rv
ARG CVC_RV_REPO_URL="https://github.com/d-m-bailey/cvc.git"
ARG CVC_RV_REPO_COMMIT="d359e88cdd2eda722360b177b57942106f0a378b"
ARG CVC_RV_NAME="cvc_rv"
USER 0:0
RUN --mount=type=bind,source=images/cvc_rv,target=/images/cvc_rv \
    bash /images/cvc_rv/scripts/install.sh
