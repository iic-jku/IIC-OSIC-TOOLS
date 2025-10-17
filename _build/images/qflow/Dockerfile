#######################################################################
# Compile qflow helper files
#######################################################################
ARG BASE_IMAGE_BUILD=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${BASE_IMAGE_BUILD} AS qflow
ARG QFLOW_REPO_URL="https://github.com/RTimothyEdwards/qflow.git"
ARG QFLOW_REPO_COMMIT="52ecda1053bcbd2f6ec88b8379c8179e2a849f7a"
ARG QFLOW_NAME="qflow"
RUN --mount=type=bind,source=images/qflow,target=/images/qflow \
    bash /images/qflow/scripts/install.sh
