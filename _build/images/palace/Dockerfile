#######################################################################
# Compile palace
#######################################################################
ARG TOOL_IMAGE_PALACE=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${TOOL_IMAGE_PALACE} AS palace
ARG PALACE_REPO_URL="https://github.com/awslabs/palace"
ARG PALACE_REPO_COMMIT="268321ea2d1f329898311a71291839030c6ed427"
ARG PALACE_NAME="palace"
RUN --mount=type=bind,source=images/palace,target=/images/palace \
    bash /images/palace/scripts/install.sh
