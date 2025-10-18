#######################################################################
# Compile palace
#######################################################################
ARG TOOL_IMAGE_PALACE="registry.iic.jku.at:5000/iic-osic-tools:tool-palace-latest"
FROM ${TOOL_IMAGE_PALACE} AS palace
ARG PALACE_REPO_URL="https://github.com/awslabs/palace"
ARG PALACE_REPO_COMMIT="v0.14.0"
ARG PALACE_NAME="palace"
RUN --mount=type=bind,source=images/palace,target=/images/palace \
    bash /images/palace/scripts/install.sh
