#######################################################################
# Compile palace
#######################################################################
ARG TOOL_IMAGE_PALACE=registry.iic.jku.at:5000/iic-osic-tools:base-dev
FROM ${TOOL_IMAGE_PALACE} AS palace
ARG PALACE_REPO_URL="https://github.com/awslabs/palace"
ARG PALACE_REPO_COMMIT="0bced454fa7eeb284d293192bbf07e3b026acc4d"
ARG PALACE_NAME="palace"
RUN --mount=type=bind,source=images/palace,target=/images/palace \
    bash /images/palace/scripts/install.sh
